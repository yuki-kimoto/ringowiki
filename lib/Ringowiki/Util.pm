package RingoWiki::Util;
use Mojo::Base -base;

has 'app';

sub setup_completed {
  my $self = shift;
  
  eval {$self->app->dbi->select(table => 'setup', where => '1 <> 1') };

  $self->app->dumper($@);
  
  return !$@ ? 1 : 0;
}

1;

