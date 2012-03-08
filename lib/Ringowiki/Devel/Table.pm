package Ringowiki::Devel::Table;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Get table info
  my $table_infos
    = $dbi->select(table => 'main.sqlite_master', where => "type='table'")->all;
  
  $self->render(table_infos => $table_infos);
}

1;

