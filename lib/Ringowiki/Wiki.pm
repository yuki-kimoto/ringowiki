package Ringowiki::Wikies;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

sub page {
  my $self = shift;
  
  $self->render;
}

1;
