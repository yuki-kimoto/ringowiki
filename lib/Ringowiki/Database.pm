package Ringowiki::Database;
use Mojo::Base 'Mojolicious::Controller';

# Create database
sub setup {
  my $self = shift;
  
  # Create entry table
  $self->app->dbi->execute(<<'EOS');
create table setup (
  rowid integer primary key autoincrement
);
EOS
  
  $self->redirect_to('/install/success');
}

1;
