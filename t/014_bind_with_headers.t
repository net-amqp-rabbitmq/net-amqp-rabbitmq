use Test::More tests => 19;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "x-nr_test_x-$unique";
my $routekey = "nr_test_route-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

eval { $mq->channel_open(1); };
is($@, '', "channel_open");

my $delete = 0;
my $queue;
eval { $queue = $mq->queue_declare(1, "", { auto_delete => $delete } ); };
is($@, '', "queue_declare");

eval { $mq->exchange_declare( 1, $exchange, { exchange_type => 'headers', auto_delete => $delete } ); };
is($@, '', "exchange_declare");

my $headers = { foo => 'bar' };
eval { $mq->queue_bind( 1, $queue, $exchange, $routekey, $headers ) };
is( $@, '', "queue_bind" );

# This message doesn't have the correct headers so will not be routed to the queue
eval { $mq->publish( 1, $routekey, "Unroutable", { exchange => $exchange } ) };
is( $@, '', "publish unroutable message" );

eval { $mq->publish( 1, $routekey, "Routable", { exchange => $exchange }, { headers => $headers} ) };
is( $@, '', "publish routable message" );

eval { $mq->consume( 1, $queue ) };
is( $@, '', "consume" );

my $msg;
eval { $msg = $mq->recv() };
is( $@, '', "recv" );
is( $msg->{body}, "Routable", "Got expected message" );

SKIP: {
	skip "Failed unbind closes channel", 1;
	eval { $mq->queue_unbind( 1, $queue, $exchange, $routekey ) };
	like( $@, qr/NOT_FOUND - no binding /, "Unbinding queue fails without specifying headers" );
}
my $message_count;
SKIP: {
	skip "Failed delete closes channel", 1;
	eval { $message_count = $mq->queue_delete( 1, $queue ) };
	like( $@, qr/PRECONDITION_FAILED - queue .* in use /, "deleting in use queue without setting if_unused fails" );
}

eval { $mq->queue_unbind( 1, $queue, $exchange, $routekey, $headers ) };
is( $@, '', "queue_unbind" );

eval { $message_count = $mq->queue_delete(1, $queue, {if_unused => 0, if_empty => 0} ); };
is( $@, '', "queue_delete" );
eval { $mq->queue_bind( 1, $queue, $exchange, $routekey, $headers ); };
like( $@, qr/NOT_FOUND - no queue /, "Binding deleted queue failed - NOT_FOUND" );

# Let's do some negative testing
my $empty_value = "";
eval { $mq->queue_bind( 1, $empty_value, $exchange, $routekey, $headers ); };
like(
	$@,
	qr/queuename and exchange must both be specified/,
	"Binding to queue without a queue name"
);
eval { $mq->queue_bind( 1, $queue, $empty_value, $routekey, $headers ); };
like(
	$@,
	qr/queuename and exchange must both be specified/,
	"Binding to queue without an exchange"
);
