use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

use Time::HiRes qw(gettimeofday tv_interval);

if ( !Net::AMQP::RabbitMQ::has_ssl ) {
  plan skip_all => 'Net::AMQP::RabbitMQ compiled without SSL support';
}

# MQSKIPSSL not set, set SSL-related options to default values unless
# already set by the user.  Those ought to work with the default
# server at rabbitmq.thisaintnews.com (which you get if you don't set
# MQHOST).

my $helper = NAR::Helper->new( ssl => 1, );

if ( $ENV{MQSKIPSSL} ) {
  plan skip_all => 'SSL tests disabled by user';
}
else {
  $helper->plan(9);
}

ok $helper->connect,      "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare,    "queue declare";
ok $helper->queue_bind,       "queue bind";
ok $helper->drain,            "drain queue";

ok $helper->consume,                  "consume";
ok $helper->publish("Magic Payload"), "publish";

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
