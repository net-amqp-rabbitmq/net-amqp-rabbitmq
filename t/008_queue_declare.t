use Test::More tests => 8;
use strict;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
my $queuename = undef;
my $message_count = 0;
my $consumer_count = 0;
my $expect_qn = 'test.net.rabbitmq.perl';
eval { ($queuename, $message_count, $consumer_count) =
         $mq->queue_declare(1, $expect_qn, { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
is($queuename, $expect_qn, "queue_declare -> $queuename = $expect_qn");
is($message_count, 0, "got message count back");
is($consumer_count, 0, "got consumer count back");
1;
