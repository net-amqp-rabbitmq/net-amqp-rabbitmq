use strict;
use Test::More;
use Data::Dumper;
use Net::AMQP::RabbitMQ;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(11);

ok $helper->connect,      "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare,    "queue declare";
ok $helper->queue_bind,       "queue bind";

my $count = 0;
ok $helper->publish("Message $count"), "Publish $count";
$count += 1;
ok $helper->publish("Message $count"), "Publish $count";
$count += 1;
ok $helper->publish("Message $count"), "Publish $count";

my $got = $helper->get;
is $got->{body}, 'Message 0', 'Got the 0th message.';

$count += 1;
ok $helper->publish("Message $count"), "Publish $count";

$helper->mq->purge($helper->{channel},$helper->{queue});

my $second_got = $helper->get;

ok !$second_got, 'no message (purged)';
