use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../exitlib/lib/perl5";

use Mojo::Base -strict;

use Test::More 'no_plan';
use Test::Mojo;

use_ok 'Ringowiki';

my $t = Test::Mojo->new('Ringowiki');
$t->get_ok('/setup')->status_is(200);
