package Ringowiki;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use Validator::Custom;
use Ringowiki::Util;

has util => sub { RingoWiki::Util->new(app => shift) };
has validator => sub { Validator::Custom->new };
has 'dbi';

sub startup {
  my $self = shift;
  
  # Config
  my $config = $self->plugin('Config');
  
  # Secret
  $self->secret($config->{secret});
  
  # Database
  my $db = $ENV{RINGOWIKI_DBNAME} || "ringowiki";
  my $dbpath = $self->home->rel_file("db/$db");
  
  # DBI
  my $dbi = DBIx::Custom->connect(
    dsn => "dbi:SQLite:$dbpath",
    option => {sqlite_unicode => 1},
    connector => 1
  );
  $self->dbi($dbi);
  
  # Route
  my $r = $self->routes;
  
  $self->dumper($self->util->setup_completed);
  
  # Brige
  my $b = $r->under(sub {
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
  $b->get('/')->to('default#default');
  
  # Setup
  $b->get('/setup')->to('setup#default');

  # Admin
  {
    my $w = $b->waypoint('/admin')->via('get')->to('admin#default');
    
    # Wiki
    {
      my $r2 = $w->route('/wiki')->to('admin-wiki#');
      $r2->get('/add')->to('#add');
    }
  }
  # API
  {
    my $r2 = $b->route('/api');
    
    # Admin
    {
      my $r3 = $r2->route('/admin')->to('api-admin#');
      $r3->post('/init')->to('#init');
      
      # Wiki
      my $r4 = $r3->route('/wiki')->to('api-admin-wiki#');
      $r4->post('add')->to('#add');
    }
    
    # Setup
    {
      $r2->post('/setup')->to('api-setup#default');
    }
  }
}

1;
