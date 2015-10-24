use Test::More tests => 15;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";

my $queuename = $helper->queue_declare( undef, undef, 1 );
ok $queuename, "queue declare";

ok $helper->queue_bind( $queuename ), "queue bind";
ok $helper->drain( $queuename ), "drain queue";

{
    my $getr = $helper->get( $queuename );
    is( $getr, undef, "get returned undef" );
}

{
    ok $helper->publish( "Magic Transient Payload" ), "publish";
    my $getr = $helper->get( $queuename, 0 );
    is_deeply(
        $getr,
        {
            redelivered   => 0,
            routing_key   => $helper->{routekey},
            exchange      => $helper->{exchange},
            message_count => 0,
            delivery_tag  => 1,
            props         => {},
            body          => 'Magic Transient Payload',
        },
        "get should see message"
    );
}

# Let's close the channel, forcing the unacknowledged message to be re-delivered.
ok $helper->channel_close, "channel_close";
ok $helper->channel_open, "channel_open";

{
# Get the message again and prove it was redelivered
    my $getr = $helper->get( $queuename );
    is_deeply(
        $getr,
        {
            redelivered   => 1,
            routing_key   => $helper->{routekey},
            exchange      => $helper->{exchange},
            message_count => 0,
            delivery_tag  => 1,
            props         => {},
            body          => 'Magic Transient Payload',
        },
        "get should see redelivered message"
    );
}

{
    my $props = {
        content_type     => 'text/plain',
        content_encoding => 'none',
        correlation_id   => '123',
        reply_to         => 'somequeue',
        expiration       => 1000,
        message_id       => 'ABC',
        type             => 'notmytype',
        user_id          => $helper->{username},
        app_id           => 'idd',
        delivery_mode    => 1,
        priority         => 2,
        timestamp        => 1271857990,
    };
    ok $helper->publish( "Magic Transient Payload 2", $props ), "publish";

    my $getr = $helper->get( $queuename );
    is_deeply(
        $getr,
        {
            redelivered   => 0,
            routing_key   => $helper->{routekey},
            exchange      => $helper->{exchange},
            message_count => 0,
            delivery_tag  => 2,
            props         => $props,
            body          => 'Magic Transient Payload 2',
        },
        "get should see message"
    );
}

END {
    ok $helper->cleanup( $queuename ), "cleanup";
}
