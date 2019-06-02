use Test::More tests => 6;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";

ok $helper->exchange_declare( {
        exchange_type => "direct",
        passive       => 0,
        durable       => 1,
        auto_delete   => 0,
        internal      => 1,
    }, "internal1.auto_delete0" ),
    "internal exchange declare";

ok $helper->exchange_declare( {
        exchange_type => "direct",
        passive       => 0,
        durable       => 1,
        auto_delete   => 1,
        internal      => 0,
    }, "internal0.auto_delete1" ),
    "direct declare auto_delete";

ok $helper->exchange_declare( {
        exchange_type => "direct",
        passive       => 0,
        durable       => 1,
        auto_delete   => 1,
        internal      => 1,
    }, "internal1.auto_delete1" ),
    "internal exchange declare auto_delete";
