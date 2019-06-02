use Test::More tests => 10;
use strict;
use warnings;
use utf8;

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

my $payload = "Message payload";
my $headers = {
    nested_array_1 => [
        123,
        {
            "inner_hash_1" => "value"
        }
    ],
    array_1 => [
        qw/
            array_1_a
            array_1_b
            array_1_c
        /
    ],
    hash_1 => {
        hash_1_a => 1,
        hash_1_b => 2,
        hash_1_c => 3,
        hash_1_d => [
            qw/
                hash_1_d_a
                hash_1_d_b
                hash_1_d_c
            /
        ],
        hash_1_e => {
            hash_1_e_f => 4,
            hash_1_e_g => 5
        }
    }
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
