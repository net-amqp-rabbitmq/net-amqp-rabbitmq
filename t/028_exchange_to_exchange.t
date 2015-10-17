use Test::More tests => 19;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchangeA = "x-nr_test_x_e2eA-$unique";
my $exchangeB = "x-nr_test_x_e2eB-$unique";
my $queue = "x-nr_test_q_e2e-$unique";
my $routekey = "nr_test_route-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

eval { $mq->channel_open(1); };
is($@, '', "channel_open");

eval { $mq->exchange_declare(1, $exchangeA, { exchange_type => "direct", passive => 0, durable => 0, auto_delete => 1 }); };
is($@, '', "exchange_declareA");

eval { $mq->exchange_declare(1, $exchangeB, { exchange_type => "fanout", passive => 0, durable => 0, auto_delete => 1 }); };
is($@, '', "exchange_declareB");

eval { $mq->queue_declare(1, $queue, { passive => 0, durable => 0, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");

eval { $mq->exchange_bind(1, $exchangeB, $exchangeA, $routekey, {"nothing"=>"nothing"})};
is($@, '', 'exchange_bind');

eval { $mq->queue_bind(1, $queue, $exchangeB, ''); };
is($@, '', "queue_bind");

eval { $mq->publish(1, $routekey, "e2e testing", { exchange => $exchangeA }, {}); };
is($@, '', "publish");
die "Fatal publish failure!" if $@;

eval { $mq->consume(1, $queue, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is($rv->{body}, 'e2e testing', 'verify body matches');

eval { $mq->exchange_unbind(1, $exchangeB, $exchangeA, $routekey, {"nothing"=>"nothing"})};
is($@, '', 'exchange_bind');

eval { $mq->queue_unbind(1, $queue, $exchangeB, $routekey); };
is($@, '', "queue_bind");


# Test parameter validation!
my $empty_value = "";
eval { $mq->exchange_bind( 1, $empty_value, $exchangeA, $routekey ); };
like(
	$@,
	qr/source and destination must both be specified/,
	"Binding exchange-to-exchange without a destination name"
);
eval { $mq->exchange_bind( 1, $exchangeB, $empty_value, $routekey ); };
like(
	$@,
	qr/source and destination must both be specified/,
	"Binding exchange-to-exchange without a source name"
);

# Now for unbinding
eval { $mq->exchange_unbind( 1, $empty_value, $exchangeA, $routekey ); };
like(
	$@,
	qr/source and destination must both be specified/,
	"Unbinding exchange-to-exchange without a destination name"
);
eval { $mq->exchange_unbind( 1, $exchangeB, $empty_value, $routekey ); };
like(
	$@,
	qr/source and destination must both be specified/,
	"Unbinding exchange-to-exchange without a source name"
);
