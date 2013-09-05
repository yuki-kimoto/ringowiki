package Ringowiki;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Ringowiki::Util;
use Ringowiki::API;
use Ringowiki::Manager;
use Scalar::Util 'weaken';
use Mojolicious::Plugin::AutoRoute::Util 'template';

has util => sub { RingoWiki::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';
has 'dbpath';
has 'manager';

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

  # Repository Manager
  my $manager = Ringowiki::Manager->new(app => $self);
  weaken $manager->{app};
  $self->manager($manager);
  
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
      
      # Database is setupped?
      unless ($self->app->util->setup_completed) {
        my $path = $self->req->url->path->to_string;
        return 1 if $path =~ m|^(/api)?/setup|;
        $self->redirect_to('/setup');
        return 0; 
      }
      
      return 1;
    });

    # SQLite viewer (only development)
    $self->plugin('DBViewer', dsn => "dbi:SQLite:$dbpath")
      if $self->mode eq 'development';
    
    # Auto routes
    $self->plugin('AutoRoute');
    
    # Main
    {
      # List wiki
      $r->get('/list-page/:wiki_id' => template 'list-page');
    
      # Edit page
      $r->get('/edit-page/:wiki_id/:page_name' => template 'edit-page');

      # Page
      $r->get('/wiki/:wiki_id/:page_name' => {page_name => undef} => template 'page');
      
      # Page history
      $r->get('/page-history/:wiki_id/:page_name' => {page_name => undef} => template 'page-history');
    }

    # API
    {
      my $r = $r->route('/api')->to('api#');

      # Setup wiki
      $r->post('/setup')->to('#setup');

      # Edit page
      $r->post('/edit-page')->to('#edit_page');

      # Preview
      $r->post('/preview')->to('#preview');
      
      # Diff
      $r->post('/content-diff')->to('#content_diff');

      if ($self->mode eq 'development') {
        # Initialize wiki
        $r->post('/init')->to('#init');
        
        # Re-setupt wiki
        $r->post('/resetup')->to('#resetup');
        
        # Create wiki
        $r->post('/create-wiki')->to('#create_wiki');
        
        # Remove all pages
        $r->post('/init-pages')->to('#init_pages');
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
}

1;
