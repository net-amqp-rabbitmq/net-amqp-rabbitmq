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

ok $helper->basic_qos( { prefetch_count => 1, global => 1 } );
ok $helper->purge(), 'Purge before starting';

# Put the channel in confirm.select
ok $helper->confirm_select;

subtest '1. No publisher confirms available' => sub {
  plan tests => 6;
  ok $helper->publish("Message 1.1"), "1.1. First Publish";
  ok $helper->publish("Message 1.2"), "1.2. Second Publish";
  my $confirm = $helper->publisher_confirm_wait(1);
  is $confirm,             undef,         '1.3. No confirms yet';
  is $helper->get()->{body}, 'Message 1.1', '1.4. Getting first message';
  ok $helper->publisher_confirm_wait(1), '1.5. Clearing ack queue';
  is $helper->get()->{body}, 'Message 1.2', '1.6. Getting first message';
};

subtest 'Two messages multiple-acked' => sub {
  plan tests => 5;

  ok $helper->publish("Message 2.1"), "2.1. First Publish";
  ok $helper->publish("Message 2.2"), "2.2. Second Publish";

  my $msg = $helper->get( undef, 0 );
  is $msg->{body}, 'Message 2.1', '2.3. Get message';
  my $confirm = $helper->publisher_confirm_wait(5);
  my $msg2    = $helper->get( undef, 0 );
  is $msg2->{body}, 'Message 2.2', '2.4. Get message';

  is_deeply
    $confirm,
    {
    channel      => 1,
    multiple     => 1,
    delivery_tag => 4,
    method       => 'basic.ack',
    },
    '2.5. Confirm two messages';
};

subtest 'Get one message, server acks publisher' => sub {
  plan tests => 3;
  ok $helper->publish("Message 3.1"), "3.1. Publish";

  my $msg = $helper->get;
  is $msg->{body}, 'Message 3.1', '3.2. Get message';
  my $confirm = $helper->publisher_confirm_wait(5);
  is_deeply
    $confirm,
    {
    channel      => 1,
    multiple     => 0,
    delivery_tag => 5,
    method       => 'basic.ack',
    },
    '3.3. One message nack';
};
