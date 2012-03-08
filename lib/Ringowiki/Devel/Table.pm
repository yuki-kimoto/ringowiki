package Ringowiki::Devel::Table;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Get table names
  # my $tables = $dbi->execute('.tables')->column;
  my $info = $dbi->select('# SELECT * FROM main.sqlite_master WHERE type='table';
  
  for my $table (@$tables) {
    
  }
  
  
  
  $self->render;
}

1;

