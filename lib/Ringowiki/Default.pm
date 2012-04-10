package Ringowiki::Default;
use Mojo::Base 'Mojolicious::Controller';

sub default {
  my $self = shift;
  
  # Goto setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  $self->render;
}

sub admin {
  my $self = shift;
  
  my $wikies = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikies => $wikies);
}

1;
