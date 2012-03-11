package Ringowiki::Admin;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

sub default {
  my $self = shift;
  
  my $wikis = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikis => $wikis);
}

1;
