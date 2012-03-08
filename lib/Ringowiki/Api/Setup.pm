package Ringowiki::Api::Setup;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

sub default {
  my $self = shift;
  
  # Validation
  my $params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    admin_user
      => {message => '管理者IDが入力されていません。'}
      => ['not_blank'],
    admin_password1
      => {message => '管理者パスワードが入力されていません。'}
      => ['ascii'],
    {admin_password => [qw/admin_password1 admin_password2/]}
       => {message => 'パスワードが一致しません。'}
       => ['duplication']
  ];
  my $vresult = $self->app->validator->validate($params, $rule);
  return $self->render_json({success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create tables
  $self->_create_table('setup', []);
  $self->_create_table('wiki', [
    'id not null unique'
  ]);
  $self->_create_table('wiki', [
    'id not null unique',
    'password not null',
    'admin not null'
  ]);
  
  $self->render(json => {success => 1});
}

sub _add_column {
  my ($self, $table, $column) = @_;

  # DBI
  my $dbi = $self->app->dbi;
  
  # Check column existance
  my $column_exist =
    eval { $dbi->select($column, where => '1 <> 1'); 1};
  return if $column_exist;
  
  # Add column
  my $sql = "alter table $table add column $column";
  $dbi->execute($sql);
  
  return 1;
}

sub _create_table {
  my ($self, $table, $columns) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Check table existance
  my $table_exist = 
    eval { $dbi->select(table => $table, where => '1 <> 1'); 1};
  return if $table_exist;
  
  # Create table
  my $sql = "create table $table (rowid integer primary key autoincrement)";
  $dbi->execute($sql);
  
  # Add columns
  $self->_add_column($table, $_) for @$columns;
  
  return 1;
}

1;
