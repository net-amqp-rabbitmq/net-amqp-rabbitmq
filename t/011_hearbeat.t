use Test::More tests => 18;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
if ( $helper->{ssl} ) {
    #openssl is awesome, it throws sigpipe on socket error
    # if we don't catch it the test will exit with code 141
    $SIG{PIPE} = 'IGNORE';
}

ok $helper->connect( 1 ), "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

note "sleeping for 10s in 1s increments";
for ( 1..10 ) {
    sleep(1);
    ok $helper->heartbeat, "heartbeat";
}

my $rv = 0;
my $props = {
    exchange  => $helper->{exchange},
    mandatory => 1,
    immediate => 1
};
ok $helper->publish( "Magic Transient Payload", $props ), "publish";

note "sleeping for 10s";
sleep(10);
ok !$helper->publish( "Magic Transient Payload", $props ), "publish fails";
