use Test::More tests => 4;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare( undef, undef, undef, { "x-single-active-consumer" => 1 } ), "declare queue with x-single-active-consumer";
