package Ringowiki::Main;
use Mojo::Base 'Mojolicious::Controller';
use Text::Markdown 'markdown';

sub admin {
  my $self = shift;
  
  my $wikies = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikies => $wikies);
}

sub index {
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
  
  # Content to html
  my $content = $page->{content};
  
  my $html = markdown $content;
  $page->{content} = $html;
  
  $self->render(page => $page);
}

1;
