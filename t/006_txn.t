use Test::More tests => 13;
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
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, '', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, "nr_test_x", "nr_test_q"); };
is($@, '', "queue_bind");
eval { $mq->tx_select(1); };
is($@, '', "tx_select");
eval { $mq->publish(1, "nr_test_q", "Magic Transient Payload", { exchange => "nr_test_x" }); };
eval { $mq->tx_rollback(1); };
is($@, '', "tx_rollback");
eval { $mq->publish(1, "nr_test_q", "Magic Transient Payload (Commit)", { exchange => "nr_test_x" }); };
eval { $mq->tx_commit(1); };
is($@, '', "tx_commit");
eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0} ); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");
$rv->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($rv,
          {
          'body' => 'Magic Transient Payload (Commit)',
          'routing_key' => 'nr_test_q',
          'delivery_tag' => $dtag,
          'exchange' => 'nr_test_x',
          'consumer_tag' => 'ctag',
          'props' => {},
          }, "payload");

1;
