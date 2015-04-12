use Test::More tests => 8;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $queuename = "nr_test_hole-$unique";
my $routekey = "nr_test_route-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 0 }); };
is($@, '', "exchange_declare");

eval { $mq->exchange_declare(1, $exchange."internal1.auto_delete0", { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 1 }); };
is($@, '', "exchange_declare");

eval { $mq->exchange_declare(1, $exchange."internal0.auto_delete1", { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 1, internal => 0 }); };
is($@, '', "exchange_declare");

eval { $mq->exchange_declare(1, $exchange."internal1.auto_delete1", { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 1, internal => 1 }); };
is($@, '', "exchange_declare");

1;
