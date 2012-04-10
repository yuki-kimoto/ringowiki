package Ringowiki;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Ringowiki::Util;

has util => sub { RingoWiki::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';
has 'dbpath';

sub startup {
  my $self = shift;
  
  # Config
  my $config = $self->plugin('Config');
  
  # Secret
  $self->secret($config->{secret});
  
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
      primary_key => ['wiki_id', 'name']
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
    }
  );
  
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

    # Top page
    $r->get('/')->to('default#default');
    
    # Setup
    $r->get('/setup')->to('setup#default');
    
    # Wiki page
    $r->get('/wikies/:wiki_id/:page_name')->to('wikies#page', page_name => '')->name('page');
    
    # Admin
    $r->get('/admin')->to('default#admin');


    # Admin
    {
      my $r = $r->waypoint('/admin')->via('get')->to('admin#default');
      
      # Wiki
      {
        my $r = $r->route('/wiki')->to('admin-wiki#');
        $r->get('/create')->to('#create');
      }
      
      # Create wiki page
      $r->get('create-wiki-page')->to('#create_wiki_page');
      
      # Edit wiki page
      $r->get('edit-wiki-page')->to('#edit_wiki_page');
    }
    
    # API
    {
      my $r = $r->route('/api')->to('api#');

      # Edit wiki page
      $r->post('/edit-wiki-page')->to('#edit_wiki_page');

      # Initialize
      $r->post('/init-wiki')->to('#init_wiki');
      
      # Setup
      $r->post('/setup')->to('#setup');

      $r->post('/setup/resetup')->to('api-setup#resetup');
      
      # Admin
      {
        my $r = $r->route('/admin')->to('api-admin#');
        
        # Wiki
        {
          my $r = $r->route('/wiki')->to('api-admin-wiki#');
          $r->post('create')->to('#create');
        }
      }
      
      # Devel
      if ($self->mode eq 'development') {
        my $r = $r->route('/devel');
        
        # SQLite viewer lite
        $self->plugin('SQLiteViewerLite', dbi => $dbi);
      }
    }
  }
}

1;
