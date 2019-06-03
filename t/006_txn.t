use Test::More tests => 13;
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

ok $helper->tx_select, 'tx_select';

    ok $helper->publish( "Magic Payload" ), "publish";

ok $helper->tx_rollback, 'tx_rollback';

    ok $helper->publish( "Magic Transient Payload (Commit)" ), "publish";

ok $helper->tx_commit, 'tx_commit';

ok $helper->consume, "consuming";

my $payload = $helper->recv;
is_deeply(
    $payload,
    {
        body         => "Magic Transient Payload (Commit)",
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
