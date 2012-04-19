use strict;
use warnings;
use Test::ModuleVersion;
use FindBin;

# Create module test
my $tm = Test::ModuleVersion->new;
$tm->before(<<'EOS');
use 5.008007;

=pod

run mvt.pl to create this module version test(t/module.t).

  perl mvt.pl

=cut

EOS
$tm->lib(['../extlib/lib/perl5']);
$tm->modules([
  ['List::MoreUtils' => '0.33'],
  [DBI => '1.618'],
  ['DBD::SQLite' => '1.35'],
  ['Object::Simple' => '3.0625'],
  ['Validator::Custom' => '0.1426'],
  ['DBIx::Custom' => '0.25'],
  [Mojolicious => '2.84'],
  ['Sub::Uplevel' => '0.24'],
  ['DBIx::Connector' => '0.51'],
  ['Algorithm::Diff' => '1.1902'],
  ['Text::Diff' => '1.41'],
  ['Test::Differences' => '0.61'],
  ['Text::Markdown' => '1.000031'],
  ['Text::Patch' => '1.8']
]);
$tm->test_script(output => "$FindBin::Bin/t/module.t");

1;
