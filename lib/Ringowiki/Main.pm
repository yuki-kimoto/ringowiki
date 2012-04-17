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
  
  # Wiki link to a
  $page->{content} = $self->_wiki_link_to_a($page->{content}, $page->{wiki_id});
  
  # Content to html(Markdown)
  $page->{content} = markdown(Ringowiki::HTMLFilter->new->filter($page->{content}));
  
  $self->render(page => $page);
}

sub _wiki_link_to_a {
  my ($self, $content, $wiki_id) = @_;
  
  my $to_a = sub {
    my ($page_name, $text) = @_;
    
    # DBI
    my $page = $self->app->dbi->model('page')->select(
      where => {wiki_id => $wiki_id, name => $page_name}
    )->one;
    
    my $link;
    if ($page) {
      $link = '<a href="'
        . $self->url_for('page', wiki_id => $wiki_id, page_name => $page_name)
        . '" class=' . ($page ? '"page_link"' : '"page_link_not_found"') . '>' . "$text</a>";
    }
    else {
      $link = '<a href="'
        . $self->url_for('edit-page', wiki_id => $wiki_id, page_name => $page_name)
        . '" class=' . ($page ? '"page_link"' : '"page_link_not_found"') . '>' . "$text</a>";
    }
    
    return $link;
  };
  
  $content =~ s/\[\[\s*(.*?)\s*?\|\s*(.*?)\s*\]\]/$to_a->($1, $2)/ge;
  $content =~ s/\[\[\s*(.*?)\s*\]\]/$to_a->($1, $1)/ge;
  
  return $content;
}

1;
