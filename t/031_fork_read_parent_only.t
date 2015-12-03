use Test::More;
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
    ok $helper->publish( "Read later" ), "publish";
    my $getr = $helper->get( $queuename, 0 );
    is_deeply(
        $getr,
        {
            redelivered   => 0,
            routing_key   => $helper->{routekey},
            exchange      => $helper->{exchange},
            message_count => 1,
            delivery_tag  => 1,
            props         => {},
            body          => 'Magic Transient Payload',
        },
        "get should see message"
    );
    ok $helper->is_connected, 'is connected ok';
}

my $pid = fork();
if (!$pid) {
    $helper->mq->do_not_disconnect_on_destroy;
    exit(0);
} else {
    waitpid($pid, 0);
    ok $helper->is_connected, 'is connected ok';
}
{
    my $getr = $helper->get( $queuename, 0 );
    is_deeply(
        $getr,
        {
            redelivered   => 0,
            routing_key   => $helper->{routekey},
            exchange      => $helper->{exchange},
            message_count => 0,
            delivery_tag  => 2,
            props         => {},
            body          => 'Read later',
        },
        "get should see message"
    );
    ok $helper->is_connected, 'is connected ok';
    $helper->ack($getr->{delivery_tag}, 1);
}

ok $helper->cleanup( $queuename ), "cleanup";
done_testing;
