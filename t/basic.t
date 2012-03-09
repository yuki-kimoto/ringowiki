use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../exitlib/lib/perl5";

use Mojo::Base -strict;

use Test::More 'no_plan';
use Test::Mojo;

use_ok 'Ringowiki';

$ENV{RINGOWIKI_DBNAME} = "$FindBin::Bin/ringowiki.db";
unlink $ENV{RINGOWIKI_DBNAME} if -f $ENV{RINGOWIKI_DBNAME};

my $t = Test::Mojo->new('Ringowiki');
$t->get_ok('/setup')->status_is(200);

$t->post_form_ok('/api/setup', {admin_user => 'admin', admin_password1 => 'a', admin_password2 => 'a'});

$t->post_form_ok('/api/setup/resetup');

END {
  unlink $ENV{RINGOWIKI_DBNAME} if -f $ENV{RINGOWIKI_DBNAME};
}
