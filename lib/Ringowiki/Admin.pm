package Ringowiki::Admin;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

sub default {
  my $self = shift;
  
  my $wikies = $self->app->dbi->model('wiki')->select->all;
  
  return $self->render(wikies => $wikies);
}

sub create_wiki_page {
  my $self = shift;
  
  $self->render;
}

1;
