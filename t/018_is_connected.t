use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(5);

ok !$helper->is_connected, "not connected";
ok $helper->connect,       "connected";
ok $helper->is_connected,  "connected";
ok $helper->disconnect,    "disconnect";
ok !$helper->is_connected, "not connected";
