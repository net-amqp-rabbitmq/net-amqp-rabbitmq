use Test::More tests => 16;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

ok $helper->publish( "Magic Payload $$" ), "publish";
ok $helper->consume( undef, 0 ), "consuming";
my $payload = $helper->recv;
is_deeply(
    $payload,
    {
        body         => "Magic Payload $$",
        channel      => 1,
        routing_key  => $helper->{routekey},
        delivery_tag => 1,
        redelivered  => 0,
        exchange     => $helper->{exchange},
        consumer_tag => $helper->{consumer_tag},
        props        => {},
    },
    "payload recived correctly"
);

ok $helper->disconnect, "disconnect";

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";
ok $helper->consume( undef, 0 ), "consuming";

my $payload2 = $helper->recv;
my $ack_tag = $payload2->{delivery_tag};
is_deeply(
    $payload2,
    {
        body         => "Magic Payload $$",
        channel      => 1,
        routing_key  => $helper->{routekey},
        delivery_tag => 1,
        redelivered  => 1,
        exchange     => $helper->{exchange},
        consumer_tag => $helper->{consumer_tag},
        props        => {},
    },
    "payload"
);
ok $helper->ack( $ack_tag ), "ack";

END {
    ok $helper->cleanup, "cleanup";
}
