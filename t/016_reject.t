use Test::More tests => 16;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $queuename = "nr_test_reject-$unique";
my $routekey = "nr_test_reject_route-$unique";

my $dtag=(unpack("L",pack("N",1)) != 1)?'0100000000000000':'0000000000000001';
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->queue_declare(1, $queuename, { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");
eval { $mq->purge(1, $queuename); };
is($@, '', "purge");
eval { $mq->publish(1, $routekey, "Magic Payload $$", { exchange => $exchange }); };
is($@, '', "publish");
eval { $mq->consume(1, $queuename, { no_ack => 0, consumer_tag=>'ctag' } ); };
is($@, '', "consuming");
my $payload = {};
eval { $payload = $mq->recv(); };
$payload->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($payload,
          {
          'body' => "Magic Payload $$",
          'routing_key' => $routekey,
          'delivery_tag' => $dtag,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => {},
          }, "payload");
eval { $mq->disconnect(); };
is($@, '', "disconnect");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->consume(1, $queuename, { no_ack => 0, consumer_tag=>'ctag' } ); };
is($@, '', "consuming");
$payload = {};
eval { $payload = $mq->recv(); };
my $reject_tag = $payload->{delivery_tag};
$payload->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($payload,
          {
          'body' => "Magic Payload $$",
          'routing_key' => $routekey,
          'delivery_tag' => $dtag,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => {},
          }, "payload");
eval { $mq->reject(1, $reject_tag); };
is($@, '', "rejecting");
