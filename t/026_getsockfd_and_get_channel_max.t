use Test::More tests => 7;
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

# Make sure trying to get a sock descriptor prior to connection is undef
is(
	$mq->get_sockfd(),
	undef,
	'getting sock prior to connection yields undef'
);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

# Make sure we can get a sock descriptor now
cmp_ok(
	$mq->get_sockfd(),
	'>',
	2, # 2 is STDERR
	'should have a valid sockfd'
);

eval { $mq->channel_open(1); };
is($@, '', "channel_open");

is(
	$mq->get_channel_max(),
	65535,
	'max channel is 65535, per documentation of librabbitmq'
);
