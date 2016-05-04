use Test::More tests => 11;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;
use Math::UInt64 qw/int64 uint64/;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";
ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

my $payload = "Message payload";
my $headers = {
    unsigned_integer => 12345,
    signed_integer   => -12345,
    double           => 2.5,
    string           => "string here",
    math_int64       => int64( "−9223372036854775808" ),
    math_uint64      => uint64( "18446744073709551615" ),
};

ok $helper->publish( $payload, { headers => $headers } ), "publish";
ok $helper->consume, "consume";

my $rv = $helper->recv;
ok $rv, "recv";

is_deeply(
    $rv,
    {
        body         => $payload,
        channel      => 1,
        routing_key  => $helper->{routekey},
        delivery_tag => 1,
        redelivered  => 0,
        exchange     => $helper->{exchange},
        consumer_tag => 'ctag',
        props        => { 'headers' => $headers },
    },
    "payload"
);

END {
    ok $helper->cleanup, "cleanup";
}
