use Test::More tests => 6;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $queuename = "x-headers-" . rand() . $unique;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

eval { $mq->channel_open(1); };
is($@, '', "channel_open");

eval { $queuename = $mq->queue_declare(1, $queuename, { auto_delete => 1 }, { "x-ha-policy" => "all" }); };
is($@, '', "queue_declare");

eval { $queuename = $mq->queue_declare(1, $queuename, { auto_delete => 0 }); };
like( $@, qr/PRECONDITION_FAILED/, "Redeclaring queue with different options fails." );
