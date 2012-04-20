package Ringowiki::Api;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Text::Diff 'diff';
use Text::Markdown 'markdown';
use Ringowiki::HTMLFilter;

our $TABLE_INFOS = {
  setup => [],
  wiki => [
    'id not null unique',
    "title not null default ''",
    "main not null default 0"
  ],
  user => [
    'id not null unique',
    'password not null',
    'admin not null',
  ],
  page => [
    'wiki_id not null',
    'name not null',
    "content not null default ''",
    'main not null default 0',
    "ctime not null default ''",
    "mtime not null default ''",
    'unique (wiki_id, name)'
  ],
  page_history => [
    "wiki_id not null default ''",
    "page_name not null default ''",
    "version not null default ''",
    "content_diff not null default ''",
    "ctime not null default ''",
    "unique (wiki_id, page_name, version)"
  ]
};

sub _init_page {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create home page
  $dbi->connector->txn(sub {
    my $wiki_id = $dbi->model('wiki')->select('id', where => {main => 1})->value;
    
    my $page_name = 'Home';
    $dbi->model('page')->insert(
      {
        wiki_id => $wiki_id,
        name => $page_name,
        content => 'Wikiをはじめよう',
        main => 1
      }
    );
    $dbi->model('page_history')->insert(
      {
        wiki_id => $wiki_id,
        page_name => $page_name,
        version => 1
      }
    );
  });
}

sub create_wiki {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    id => ['word'],
    title => ['any']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  return $self->render(json => {success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  my $params = $vresult->data;
  $params->{title} = '未設定' unless length $params->{title};
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Transaction
  $dbi->connector->txn(sub {
  
    # Create wiki
    my $mwiki = $dbi->model('wiki');
    $params->{main} = 1 unless $mwiki->select->one;
    $mwiki->insert($params);
    
    # Initialize page
    $dbi->_init_page;
  });
  
  $self->render(json => {success => 1});
}

sub edit_page {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['not_blank'],
    page_name => {require => ''} => ['not_blank'],
    content => ['any']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  return $self->render(json => {success => 0, validation => $vresult->to_hash})
    unless $vresult->is_ok;
  my $params = $vresult->data;
  my $wiki_id = $params->{wiki_id};
  my $page_name = $params->{page_name};
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Transaction
  my $mpage = $dbi->model('page');
  my $mpage_history = $dbi->model('page_history');
  $dbi->connector->txn(sub {

    # Page exists?
    my $page_history = $mpage_history->select(
      id => [$wiki_id, $page_name])->one;
    my $page_exists = $page_history ? 1 : 0;
    
    # Edit page
    if ($page_exists) {
      # Content
      my $page = $mpage->select(id => [$wiki_id, $page_name])->one;
      my $content = $page->{content};
      my $content_new = $params->{content};
    
      # No change
      return $self->render_json({success => 1})
        if $content eq $content_new;
      
      # Content diff
      my $content_diff = diff(\$content, \$content_new, {STYLE => 'Unified'});
      my $max_version = $mpage_history->select(
        'max(version) as max',
        id => [$wiki_id, $page_name]
      )->value;
      
      # Create page history
      $mpage_history->insert(
        {content_diff => $content_diff, version => $max_version + 1},
        id => [$wiki_id, $page_name]
      );
      
      # Update page
      $mpage->update(
        {content => $content_new},
        id => [$wiki_id, $page_name]
      );
    }
    # Create page
    else {
      my $content_new = $params->{content};
      my $empty = '';

      my $content_diff = diff \$empty, \$content_new, {STYLE => 'Unified'};
      $mpage_history->insert(
        {wiki_id => $wiki_id, page_name => $page_name, version => 1});
      $mpage->insert(
        {wiki_id => $wiki_id, name => $page_name, content => $content_new});
    }
  });
  if ($@) {
    $self->app->log->error($@);
    return $self->render(json => {success => 0});
  }
  
  # Render
  $self->render(json => {success => 1});
}

sub preview {
  my $self = shift;
  
  # Validation
  my $raw_params = {map { $_ => $self->param($_) } $self->param};
  my $rule = [
    wiki_id => ['word'],
    page_name => ['not_blank'],
    content => ['any']
  ];
  my $vresult = $self->app->validator->validate($raw_params, $rule);
  my $params = $vresult->data;
  my $wiki_id = $params->{wiki_id};
  my $page_name = $params->{page_name};
  my $content = $params->{content};
  
  # Exception
  return $self->render(json => {success => 0})
    unless defined $wiki_id && defined $page_name && defined $content;
  
  # HTML filter
  my $hf = Ringowiki::HTMLFilter->new;
  
  # Prase wiki link
  $content = $hf->parse_wiki_link($self, $content, $wiki_id);
  
  # Sanitize and Markdown
  $content = markdown $hf->sanitize_tag($content);
  
  # Render
  $self->render(json => {
    success => 1,
    page => {
      wiki_id => $wiki_id,
      name => $page_name,
      content => $content
    }
  });
}

sub init {
  my $self = shift;
  
  my $dbi = $self->app->dbi;
  
  my $table_infos = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name <> 'sqlite_sequence'"
  )->all;
  
  eval {
    $dbi->connector->txn(sub {
      for my $table_info (@$table_infos) {
        my $table = $table_info->{name};
        $self->app->dbi->execute("drop table $table");
      }
    });
  };
  
  my $success = !$@ ? 1 : 0;
  return $self->render_json({success => $success});
}

sub init_pages {
  my $self = shift;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  eval {
    # Remove all page
    $dbi->connector->txn(sub {
      
      # Remove pages
      $dbi->model('page')->delete_all;
      
      # Remove page histories
      $dbi->model('page_history')->delete_all;
      
      # Initialize page
      $self->_init_page;
    });
  };
  
  if ($@) {
    $self->app->log->error($@);
    return $self->render(json => {success => 0});
  }
  
  return $self->render(json => {success => 1});
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
  )->values;
  $dbi->execute("drop table $_") for @$new_tables;

  # Drop old tables
  my $old_tables = $dbi->select(
    column => 'name',
    table => 'main.sqlite_master',
    where => "type = 'table' and name like '$prefix_old%'"
  )->values;
  $dbi->execute("drop tabe $_") for @$old_tables;
  
  # Create new tables
  eval {
    $self->_create_table("$prefix_new$_" => $TABLE_INFOS->{$_}) for keys %$TABLE_INFOS;
  };
  if ($@) {
    $self->app->log->error($@);
    return $self->render(json => {success => 0});
  }
  
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
      $new_columns->{$row->{name}} = 1; 
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
  
  # Cleanup
  $dbi->execute('vacuum');
  
  $self->render_json({success => 1});
}

sub setup {
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
