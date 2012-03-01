package Ringowiki::Api::Setup;
use Mojo::Base 'Mojolicious::Controller';

sub default {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create "setup" table
  $self->_create_table(
    'setup', 
    [
      'rowid integer primary key autoincrement'
    ]
  );
  
  # Create "wiki" table
  $self->_create_table(
    'wiki',
    [
      'rowid integer primary key autoincrement',
      'id not null unique'
    ]
  );
  
  $self->render(json => {success => 1});
}

sub _create_table {
  my ($self, $table, $rows) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Check table existance
  my $table_exists = 
    eval { $dbi->select(table => $table, where => '1 <> 1'); 1};
  
  # Create table
  unless ($table_exists) {
    my $sql = "create table $table (\n";
    $sql .= join(", \n", @$rows);
    $sql .= "\n)\n";
    
    $dbi->execute($sql);
  }
}

1;
