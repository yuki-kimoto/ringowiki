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

sub select {
  my $self = shift;
  
  # Parameter
  my $table = $self->param('table');
  return $self->render(table => '') unless defined $table;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Select
  my $result = $dbi->select(table => $table);
  
  $self->render(
    table => $table,
    header => $result->header,
    rows => $result->fetch_all
  );
}

1;
