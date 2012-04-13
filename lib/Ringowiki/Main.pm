package Ringowiki::Main;
use Mojo::Base 'Mojolicious::Controller';

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
  
  my $wiki_id = 'main';
  my $page_name = '';
  
  $self->render(wiki_id => $wiki_id, page_name => $page_name);
}

1;
