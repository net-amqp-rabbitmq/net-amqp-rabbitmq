use Test::More tests => 11;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect( 1 ), "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

note "sleeping for 1s";
sleep(1);
ok $helper->heartbeat, "heartbeat";

my $rv = 0;
my $props = {
    exchange  => $helper->{exchange},
    mandatory => 1,
    immediate => 1
};
ok $helper->publish( "Magic Transient Payload", $props ), "publish";

note "sleeping for 5s";
sleep(5);
ok !$helper->publish( "Magic Transient Payload", $props ), "publish fails";
ok !$helper->is_connected, "not connected";

END {
    #reconect to cleanup
    $helper->connect;
    $helper->channel_open;
    ok $helper->cleanup, "cleanup";
}
