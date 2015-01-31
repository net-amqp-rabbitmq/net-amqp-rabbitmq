use Test::More tests => 9;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $expect_qn = "test.amqp.net.rabbitmq.perl-$unique";
my $routekey = "nr_test_route-$unique";

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
eval { ($queuename, $message_count, $consumer_count) =
         $mq->queue_declare(1, $expect_qn, { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
is($queuename, $expect_qn, "queue_declare -> $queuename = $expect_qn");
is($message_count, 0, "got message count back");
is($consumer_count, 0, "got consumer count back");


my $original_queue = 'test1';
my $messageTTL = 10;

my $queue_options = {
        'x-dead-letter-exchange'    => 'amq.direct',
        'x-dead-letter-routing-key' => $expect_qn,
        'x-message-ttl'             => 10000,
        'x-expires'                 => 20000,
        };
my $delay_queue = eval {
	$mq->queue_declare(1,
        	"",
        	{ auto_delete => 1, },
        	$queue_options,
        	);
};

is($@, '', "queue_declare");

1;
