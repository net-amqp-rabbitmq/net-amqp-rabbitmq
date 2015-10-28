use Test::More tests => 21;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

use Time::HiRes qw(gettimeofday tv_interval);

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

ok $helper->publish( "Magic Payload $$" ), "publish";
ok $helper->consume( undef, 0 ), 'consume';

{
    my $payload = $helper->recv;
    ok $payload, "recv";

    is_deeply(
        $payload,
        {
            body         => "Magic Payload $$",
            routing_key  => $helper->{routekey},
            delivery_tag => 1,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => {},
        },
        "payload"
    );
}
ok $helper->disconnect, "disconnect";

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";
ok $helper->consume( undef, 0 ), 'consume';

{
    my $payload = $helper->recv;
    ok $payload, "recv";

    is_deeply(
        $payload,
        {
            body         => "Magic Payload $$",
            routing_key  => $helper->{routekey},
            delivery_tag => 1,
            redelivered  => 1,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => {},
        },
        "payload"
    );

    my $reject_tag = $payload->{delivery_tag};

    ok $helper->reject( $reject_tag ), "reject";
}

{
    ok $helper->publish( "Magic Payload $$" ), "publish";
    my $payload = $helper->recv;
    ok $payload, "recv";

    my $nack_tag = $payload->{delivery_tag};
    ok $helper->nack( $nack_tag ), "nack";
}

END {
    ok $helper->cleanup, "cleanup";
}
