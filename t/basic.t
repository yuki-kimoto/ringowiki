use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../exitlib/lib/perl5";

use Mojo::Base -strict;

use Test::More tests => 4;
use Test::Mojo;

use_ok 'Ringowiki';

my $t = Test::Mojo->new('Ringowiki');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
