package Ringowiki::API;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Text::Diff 'diff';
use Text::Markdown 'markdown';
use Ringowiki::HTMLFilter;

use Digest::MD5 'md5_hex';

has 'cntl';

sub app { shift->cntl->app }

sub encrypt_password {
  my ($self, $password) = @_;
  
  my $salt;
  $salt .= int(rand 10) for (1 .. 40);
  my $password_encryped = md5_hex md5_hex "$salt$password";
  
  return ($password_encryped, $salt);
}

sub check_password {
  my ($self, $password, $salt, $password_encrypted) = @_;
  
  return unless defined $password && $salt && $password_encrypted;
  
  return md5_hex(md5_hex "$salt$password") eq $password_encrypted;
}

sub new {
  my ($class, $cntl) = @_;

  my $self = $class->SUPER::new(cntl => $cntl);
  
  return $self;
}

sub logined_admin {
  my $self = shift;

  # Controler
  my $c = $self->cntl;
  
  # Check logined as admin
  my $user = $c->session('user');
  
  return $self->is_admin($user) && $self->logined($user);
}

sub logined {
  my ($self, $user) = @_;
  
  my $c = $self->cntl;
  
  my $dbi = $c->app->dbi;
  
  my $current_user = $c->session('user');
  my $password = $c->session('password');
  return unless defined $password;
  
  my $correct_password
    = $dbi->model('user')->select('password', id => $current_user)->value;
  return unless defined $correct_password;
  
  my $logined;
  
  if (defined $user) {
    $logined = $user eq $current_user && $password eq $correct_password;
  }
  else {
    $logined = $password eq $correct_password
  }
  
  return $logined;
}

sub params {
  my $self = shift;
  
  my $c = $self->cntl;
  
  my %params;
  for my $name ($c->param) {
    my @values = $c->param($name);
    if (@values > 1) {
      $params{$name} = \@values;
    }
    elsif (@values) {
      $params{$name} = $values[0];
    }
  }
  
  return \%params;
}

sub _init_page {
  my ($self, $wiki_id) = @_;
  
  # DBI
  my $dbi = $self->app->dbi;
  
  # Create home page
  $dbi->connector->txn(sub {
    
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

sub _get_default_page {
  my ($self, $wiki_id, $page_name) = @_;
  
  #DBI
  my $dbi = $self->app->dbi;
  
  # Wiki id
  unless (defined $wiki_id) {
    $wiki_id = $dbi->model('wiki')->select('id', append => 'order by main desc')->value;
  }
  
  # Page name
  unless (defined $page_name) {
    $page_name = $dbi->model('page')->select(
      'name',
      where => {wiki_id => $wiki_id},
      append => 'order by main desc'
    )->value;
  }
  
  return ($wiki_id, $page_name);
}

sub admin_user {
  my $self = shift;
  
  # Admin user
  my $admin_user = $self->app->dbi->model('user')
    ->select(where => {admin => 1})->one;
  
  return $admin_user;
}

sub is_admin {
  my ($self, $user) = @_;
  
  # Check admin
  my $is_admin = $self->app->dbi->model('user')
    ->select('admin', id => $user)->value;
  
  return $is_admin;
}

sub users {
  my $self = shift;
  
  # Users
  my $users = $self->app->dbi->model('user')->select(
    where => [':admin{<>}',{admin => 1}],
    append => 'order by id'
  )->all;
  
  return $users;
}

sub exists_user {
  my ($self, $user) = @_;
  
  # Exists project
  my $row = $self->app->dbi->model('user')->select(id => $user)->one;
  
  return $row ? 1 : 0;
}

1;
