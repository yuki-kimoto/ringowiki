package Ringowiki::Default;
use Mojo::Base 'Mojolicious::Controller';

sub default {
  my $self = shift;
  
  # Goto setup page
  return $self->redirect_to('/setup')
    unless $self->app->util->setup_completed;
  
  $self->render;
}

1;
