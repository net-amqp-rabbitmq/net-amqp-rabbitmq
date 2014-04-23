use Test::More tests => 16;
use strict;

my $dtag=(unpack("L",pack("N",1)) != 1)?'0100000000000000':'0000000000000001';
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->queue_declare(1, "nr_test_ack", { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");
eval { $mq->queue_bind(1, "nr_test_ack", "nr_test_x", "nr_test_ack_route"); };
is($@, '', "queue_bind");
eval { $mq->purge(1, "nr_test_ack"); };
is($@, '', "purge");
eval { $mq->publish(1, "nr_test_ack_route", "Magic Payload $$", { exchange => "nr_test_x" }); };
is($@, '', "publish");
eval { $mq->consume(1, "nr_test_ack", { no_ack => 0, consumer_tag=>'ctag' } ); };
is($@, '', "consuming");
my $payload = {};
eval { $payload = $mq->recv(); };
$payload->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($payload,
          {
          'body' => "Magic Payload $$",
          'routing_key' => 'nr_test_ack_route',
          'delivery_tag' => $dtag,
          'exchange' => 'nr_test_x',
          'consumer_tag' => 'ctag',
          'props' => {},
          }, "payload");
eval { $mq->disconnect(); };
is($@, '', "disconnect");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->consume(1, "nr_test_ack", { no_ack => 0, consumer_tag=>'ctag' } ); };
is($@, '', "consuming");
$payload = {};
eval { $payload = $mq->recv(); };
my $ack_tag = $payload->{delivery_tag};
$payload->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($payload,
          {
          'body' => "Magic Payload $$",
          'routing_key' => 'nr_test_ack_route',
          'delivery_tag' => $dtag,
          'exchange' => 'nr_test_x',
          'consumer_tag' => 'ctag',
          'props' => {},
          }, "payload");
eval { $mq->ack(1, $ack_tag); };
is($@, '', "acking");

1;
