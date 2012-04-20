package Ringowiki::Main;
use Mojo::Base 'Mojolicious::Controller';
use Text::Markdown 'markdown';
use Ringowiki::HTMLFilter;

sub admin {
  my $self = shift;
  
  my $wikies = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikies => $wikies);
}

sub edit_page {
  my $self = shift;
  
  my $wiki_id = $self->param('wiki_id');
  my $page_name = $self->param('page_name');
  
  # Exeption
  return $self->render_exeption unless defined $wiki_id && defined $page_name;
  
  # Wiki exists?
  my $wiki = $self->app->dbi->model('wiki')->select(
    where => {id => $wiki_id}
  )->one;
  
  # Not found
  return $self->render_not_found unless $wiki;
  
  # Page
  my $page = $self->app->dbi->model('page')->select(
    where => {wiki_id => $wiki_id, name => $page_name}
  )->one;
  $page = {not_exists => 1, wiki_id => $wiki_id, name => $page_name, content => ''}
    unless $page;
  
  # Render
  $self->render(page => $page);
}

sub top {
  my $self = shift;
  
  # Redirect to setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  # Redirect to main wiki
  my $wiki = $self->app->dbi->model('wiki')
    ->select(append => 'order by main desc')->one;
  if ($wiki) {
    return $self->redirect_to(
      'page',
      wiki_id => $wiki->{id},
    );
  }
  
  $self->render;
}

sub list_wiki {
  my $self = shift;
  
  # Pages
  my $wiki_id = $self->param('wiki_id');
  my $pages = $self->app->dbi->model('page')->select(
    where => {wiki_id => $wiki_id},
    append => 'order by name'
  )->all;
  
  # Not found
  return $self->render_not_found unless @$pages;
  
  # Render
  $self->render(pages => $pages);
}

sub page {
  my $self = shift;

  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['word'],
    page_name => ['not_blank']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  my $params = $vresult->data;

  # DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id
  my $wiki_id = $params->{wiki_id};
  unless (defined $wiki_id) {
    $wiki_id = $dbi->model('wiki')->select('id', append => 'order by main desc')->value;
  }
  
  # Page name
  my $page_name = $params->{page_name};
  unless (defined $page_name) {
    $page_name = $dbi->model('page')->select(
      'name',
      where => {wiki_id => $wiki_id},
      append => 'order by main desc'
    )->value;
  }
  
  # Page
  my $page = $dbi->model('page')->select(
    where => {wiki_id => $wiki_id, name => $page_name},
  )->one;

  return $self->render_not_found unless defined $page;
  
  # HTML Filter
  my $hf = Ringowiki::HTMLFilter->new;
  
  # Wiki link to a
  $page->{content} = $hf->parse_wiki_link($self, $page->{content}, $page->{wiki_id});
  
  # Content to html(Markdown)
  $page->{content} = markdown($hf->sanitize_tag($page->{content}));
  
  $self->render(page => $page);
}

1;
