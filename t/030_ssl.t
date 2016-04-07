use Test::More tests => 10;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

use Time::HiRes qw(gettimeofday tv_interval);

my $helper = NAR::Helper->new(
    ssl        => 1,
    port       => 5673,
    host       => 'rabbitmq.thisaintnews.com',
    ssl_cacert => "$Bin/ssl/cacert.pem",
    ssl_init   => 1,
    username   => 'nartest',
    password   => 'reallysecure',
);

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

ok $helper->consume, "consume";
ok $helper->publish( "Magic Payload" ), "publish";

my $rv = $helper->recv;

is_deeply(
    $rv,
    {
        body         => 'Magic Payload',
        channel      => 1,
        routing_key  => $helper->{routekey},
        delivery_tag => 1,
        redelivered  => 0,
        exchange     => $helper->{exchange},
        consumer_tag => $helper->{consumer_tag},
        props        => {},
    },
    "payload matches"
);

END {
    ok $helper->cleanup, "cleanup";
}
