use Test::More tests => 13;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x_ae-$unique";
my $ae_exchange = "ae_nr_test_x_ae-$unique";
my $queuename = "nr_test_hole_ae-$unique";
my $routekey = "nr_test_route_ae-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->exchange_declare(1, $ae_exchange, { exchange_type => "fanout", passive => 0, durable => 1, auto_delete => 0 }); };
is($@, '', "exchange_declare for ae");

eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0 }, { "alternate-exchange" => $ae_exchange } ); };
is($@, '', "exchange_declare for main exchange");

eval { $mq->queue_declare(1, $queuename, { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");

eval { $mq->queue_bind(1, $queuename, $ae_exchange, $routekey); };
is($@, '', "queue_bind");
eval { 1 while($mq->get(1, $queuename)); };
is($@, '', "drain queue");

eval {
	$mq->publish(
		1,
		$routekey,
		"Magic Payload", 
		{ exchange => $exchange },
		{},
	);
};
is($@, '', "publish");

my $getr = undef;
eval { $getr = $mq->get(1, $queuename); };
is($@, '', "get");

is( $getr->{'body'}, "Magic Payload", "Verify payload is the same" );
is( $getr->{'exchange'}, $exchange, "Verify it was indeed sent to the original exchange");

1;
