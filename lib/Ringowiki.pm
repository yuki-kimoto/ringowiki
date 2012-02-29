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
  
  # Model
  $dbi->create_model(table => 'entry');
  
  # Route
  my $r = $self->routes;
  
  $self->dumper($self->util->setup_completed);
  
  # Brige
  my $b = $r->under(sub {
    my $self = shift;
    
    # Database is setupped?
    unless ($self->app->util->setup_completed) {
      my $path = $self->req->url->path->to_string;
      return 1 if $path eq '/install' || $path eq '/database/setup';
      $self->redirect_to('/install');
      return 0; 
    }
    
    return 1;
  });

  # Top page
  $b->get('/')->to('default#default');
  
  # Admin
  $b->get('/admin')->to('admin#default');

  # Entry
  $b->post('/entry/create')->to('entry#create');

  # Install
  $b->get('/install')->to('install#default');
  $b->get('/install/success')->to('install#success');

  # Database
  $b->post('/database/setup')->to('database#setup');
}

1;
