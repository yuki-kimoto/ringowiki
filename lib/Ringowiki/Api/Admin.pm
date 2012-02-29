package Ringowiki::Api::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub init {
  my $self = shift;
  
  my $success = eval {
    $self->app->dbi->execute("drop table setup");
    1;
  };
  
  return $self->render_json({success => $success});
}

1;
