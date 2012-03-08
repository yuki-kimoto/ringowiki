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
  $dbi->connector->txn(sub {
    $self->_create_table('setup', []);
    $self->_create_table('wiki', [
      'id not null unique'
    ]);
    $self->_create_table('user', [
      'id not null unique',
      'password not null',
      'admin not null'
    ]);
  });
  
  $self->render(json => {success => 1});
}

sub _create_table {
  my ($self, $table, $columns) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Check table existance
  my $table_exist = 
    eval { $dbi->select(table => $table, where => '1 <> 1'); 1};
  
  # Create table
  unshift @$columns, 'rowid integer primary key autoincrement';
  unless ($table_exist) {
    my $sql = "create table $table (";
    $sql .= join ', ', @$columns;
    $sql .= ')';
    $dbi->execute($sql);
  }
}

1;
