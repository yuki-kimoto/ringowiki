package Ringowiki;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Ringowiki::API;
use Scalar::Util 'weaken';
use Mojolicious::Plugin::AutoRoute::Util 'template';
use Carp 'croak';

has util => sub { RingoWiki::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';
has 'dbpath';

sub startup {
  my $self = shift;
  
  # Config file
  $self->plugin('INIConfig', {ext => 'conf'});
  
  # Config file for developper
  unless ($ENV{RINGOWIKI_NO_MYCONFIG}) {
    my $my_conf_file = $self->home->rel_file('ringowiki.my.conf');
    $self->plugin('INIConfig', {file => $my_conf_file}) if -f $my_conf_file;
  }
  
  # Listen
  my $conf = $self->config;
  my $listen = $conf->{hypnotoad}{listen} ||= ['http://*:10050'];
  $listen = [split /,/, $listen] unless ref $listen eq 'ARRAY';
  $conf->{hypnotoad}{listen} = $listen;  

  # Database
  my $db = "ringowiki";
  my $dbpath = $ENV{RINGOWIKI_DBPATH} // $self->home->rel_file("db/$db");
  $self->dbpath($dbpath);
  
  # DBI
  my $dbi = DBIx::Custom->connect(
    dsn => "dbi:SQLite:$dbpath",
    option => {sqlite_unicode => 1},
    connector => 1
  );
  $self->dbi($dbi);
  
  # Models
  my $models = [
    # Wiki
    {
      table => 'wiki',
      primary_key => 'id'
    },
    
    # Page
    {
      table => 'page',
      primary_key => ['wiki_id', 'name'],
      ctime => 'ctime',
      mtime => 'mtime'
    },
    
    # Page History
    {
      table => 'page_history',
      primary_key => ['wiki_id', 'page_name', 'version'],
      ctime => 'ctime'
    },
    
    # User
    {
      table => 'user',
      primary_key => 'id'
    }
  ];
  $dbi->create_model($_) for @$models;
  
  # Validator;
  my $vc = $self->validator;
  $vc->register_constraint(
    word => sub {
      my $value = shift;
      return 0 unless defined $value;
      return $value =~ /^[a-zA-Z_]+$/ ? 1 : 0;
    },
    user_name => sub {
      my $value = shift;
      
      return ($value || '') =~ /^[a-zA-Z0-9_\-]+$/
    },
    wiki_name => sub {
      my $value = shift;
      
      return ($value || '') =~ /^[a-zA-Z0-9_\-]+$/
    }
  );
  $self->validator($vc);
  
  # Route
  my $r = $self->routes;

  # Brige
  {
    my $r = $r->under(sub {
      my $self = shift;
      
      my $api = $self->wiki_api;
      
      # If admin user don't exists, redirect to _start page
      my $admin_user = $api->admin_user;
      unless (defined $admin_user && length $admin_user) {
        my $path_parts = $self->url_for->path->parts;
        unless (@$path_parts && $path_parts->[0] eq '_start') {
          $self->redirect_to('/_start');
          return;
        }
      }
      
      return 1;
    });

    # DBViewer (/dbviewer)
    $self->plugin('DBViewer', dsn => "dbi:SQLite:$dbpath", route => $r)
      if $self->mode eq 'development';

    $r->any('/' => template 'page');
    
    # Auto routes
    $self->plugin('AutoRoute', route => $r);
    
    {
      # Wikis
      # my $r = $r->route("/:wiki_id");
      
      # List page
      $r->any('/_pages' => template '_pages');
      
      {
        # Page
        $r->any("/_create/:page_name" => {page_name => undef} => template '_create');
        
        # Edit page
        $r->any('/_edit/:page_name' => template '_edit');

        # Page history
        $r->any('/_page-history/:page_name' => {page_name => undef} => template '_page-history');

        # Page
        $r->any("/:page_name" => {page_name => undef} => template 'page');
      }
    }
  }
  
  # Helper
  $self->helper(wiki_api => sub { Ringowiki::API->new(shift) });

  # Reverse proxy support
  my $reverse_proxy_on = $self->config->{reverse_proxy}{on};
  my $path_depth = $self->config->{reverse_proxy}{path_depth};
  if ($reverse_proxy_on) {
    $ENV{MOJO_REVERSE_PROXY} = 1;
    if ($path_depth) {
      $self->hook('before_dispatch' => sub {
        my $self = shift;
        for (1 .. $path_depth) {
          my $prefix = shift @{$self->req->url->path->parts};
          push @{$self->req->url->base->path->parts}, $prefix;
        }
      });
    }
  }
  
  # Setup database
  $self->setup_database;
}

my $table_infos = {
  wiki => {
    primary_keys => ['id'],
    columns => [
      ["title", "not null default ''"],
    ]
  },
  user => {
    primary_keys => ['id'],
    columns => [
      ["password", "not null default ''"],
      ["admin", "not null default ''"],
      ["salt", "not null default ''"]
    ]
  },
  page => {
    primary_keys => ['wiki_id', 'name'],
    columns => [
      ["content", "not null default ''"],
      ["main", "not null default 0"],
      ["ctime", "not null default ''"],
      ["mtime", "not null default ''"]
    ]
  },
  page_history => {
    primary_keys => ['wiki_id', 'page_name', 'version'],
    columns => [
      ["content_diff", "not null default ''"],
      ["user", "not null default ''"],
      ["message", "not null default ''"],
      ["ctime", "not null default ''"],
    ]
  }
};

sub setup_database {
  my $self = shift;
  
  my $dbi = $self->app->dbi;
  
  for my $table_name (keys %$table_infos) {
    my $table_info = $table_infos->{$table_name};
    my $primary_keys = $table_info->{primary_keys};
    
    my $columns = $table_info->{columns};
    
    # Create table
    my $create_table = "create table $table_name (row_id integer primary key autoincrement, ";
    $create_table .= join ',', map { "$_ not null" } @$primary_keys;
    $create_table .= ', unique(' . join(',', @$primary_keys) . '))';
    eval { $dbi->execute($create_table) };
    
    # Add columns
    for my $column (@$columns) {
      my $add_column = "alter table $table_name add column $column->[0] $column->[1]";
      eval { $dbi->execute($add_column) };
    }

    # Check user table
    eval { $dbi->select([@$primary_keys, map { $_->[0] } @$columns], table => $table_name) };
    if ($@) {
      my $error = "Can't create $table_name table properly: $@";
      $self->app->log->error($error);
      croak $error;
    }
  }
}

1;
