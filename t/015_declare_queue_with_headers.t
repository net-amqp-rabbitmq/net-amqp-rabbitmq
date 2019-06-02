use Test::More tests => 5;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare( { auto_delete => 1 }, undef, undef, { "x-ha-policy" => "all" } ), "queue declare";

ok !$helper->queue_declare( { auto_delete => 0 } ), "Redeclaring queue with different options fails";
