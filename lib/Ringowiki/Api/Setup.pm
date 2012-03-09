package Ringowiki::Api::Setup;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

our $TABLE_INFOS = {
  setup => [],
  wiki => [
    'id not null unique'
  ],
  user => [
    'id not null unique',
    'password not null',
    'admin not null',
  ]
};

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
    $self->_create_table($_, $TABLE_INFOS->{$_}) for keys %$TABLE_INFOS;
  });
  
  $self->render(json => {success => 1});
}

sub resetup {
  my $self = shift;
  
  # Prefix
  my $prefix_new = '__ringowiki_new__';
  my $prefix_old = '__ringowiki_old__';
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Drop new tables
  my $new_tables = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name like '$prefix_new%'"
  )->column;
  $dbi->execute("drop table $_") for @$new_tables;

  # Drop old tables
  my $old_tables = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name like '$prefix_old%'"
  )->column;
  $dbi->execute("drop tabe $_") for @$old_tables;
  
  # Create new tables
  $DB::single = 1;
  $self->_create_table("$prefix_new$_" => $TABLE_INFOS->{$_}) for keys %$TABLE_INFOS;
  
  # Get current tables
  my %current_tables = $dbi->select(
    column => 'name, 1',
    table => 'main.sqlite_master',
    where => "type = 'table' and name <> 'sqlite_sequence' and not name like '$prefix_new%'"
  )->flat;

  # Copy current table to new table
  for my $table (keys %$TABLE_INFOS) {
    next unless $current_tables{$table};
    
    my $new_column_info_result = $dbi->execute("PRAGMA TABLE_INFO('$prefix_new$table')");
    my $new_columns = {};
    while (my $row = $new_column_info_result->fetch_hash) {
      $new_columns->{$row->{name}};
    }
    
    my $current_column_info_result = $dbi->execute("PRAGMA TABLE_INFO('$table')");
    my @current_columns;
    while (my $row = $current_column_info_result->fetch_hash) {
      push @current_columns, $row->{name};
    }
    
    my @columns = grep { $new_columns->{$_} } @current_columns;
    my $columns = join ', ', @current_columns;
    
    my $result = $dbi->select($columns, table => $table);
    my $new_table = "$prefix_new$table";
    while (my $row = $result->fetch_hash) {
      $dbi->insert($row, table => $new_table);
    }
  }
  
  # Rename table
  $dbi->connector->txn(sub {
    # Rename current table to old
    $dbi->execute("alter table $_ rename to $prefix_old$_")
      for keys %current_tables;
    
    # Rename new table to current
    $dbi->execute("alter table $prefix_new$_  rename to $_")
      for keys %$TABLE_INFOS;
  });
  
  # Drop old table
  $dbi->execute("drop table $prefix_old$_")
    for keys %current_tables;
  
  $dbi->execute('vacuum');
  
  $self->render_json({success => 1});
}

sub _create_table {
  my ($self, $table, $columns) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Check table existance
  my $table_exist = 
    eval { $dbi->select(table => $table, where => '1 <> 1'); 1};
  
  # Create table
  $columns = ['rowid integer primary key autoincrement', @$columns];
  unless ($table_exist) {
    my $sql = "create table $table (";
    $sql .= join ', ', @$columns;
    $sql .= ')';
    $dbi->execute($sql);
  }
}

1;
