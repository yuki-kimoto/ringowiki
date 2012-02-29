package Ringowiki::Install;
use Mojo::Base 'Mojolicious::Controller';

sub default {
  my $self = shift;
  
  # Database is setupped
  if ($self->app->util->setup_completed) {
    $self->redirect_to('/admin');
  }
  else { $self->render }
}

1;
