package Ringowiki::Api::Setup;
use Mojo::Base 'Mojolicious::Controller';

sub default {
  my $self = shift;
  
  # Database is setupped
  return $self->render(json => {success => 0})
    if $self->app->util->setup_completed;
  
  # Create setup table
  $self->app->dbi->execute(<<'EOS');
create table setup (
  rowid integer primary key autoincrement
);
EOS
  
  $self->render(json => {success => 1});
}

1;
