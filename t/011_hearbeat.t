use Test::More tests => 6;
use strict;
use Data::Dumper;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";
$SIG{'PIPE'} = 'IGNORE';
use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest", heartbeat => 1 }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
diag "Sleeping for 5 seconds";
sleep(5);
eval { $mq->heartbeat(); };
is($@, '', "heartbeat");
my $rv = 0;
eval { $mq->publish(1, "nr_test_q", "Magic Transient Payload", { exchange => "nr_test_x", "immediate" => 1, "mandatory" => 1 }); };
diag "Sleeping for 1 seconds";
sleep(1);
eval { $mq->publish(1, "nr_test_q", "Magic Transient Payload", { exchange => "nr_test_x", "immediate" => 1, "mandatory" => 1 }); };
like( $@, qr/Publish failed, error code -9/, "publish fails with error code" );
