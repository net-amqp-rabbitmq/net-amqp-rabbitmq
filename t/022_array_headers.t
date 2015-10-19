use Test::More tests => 12;
use strict;
use warnings;
use utf8;

use Math::UInt64 qw/uint64/;
use Data::Dumper;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V-$$"; #hostname-os-perlversion-PID
my $exchange = "nr_test_x-array_headers-$unique";
my $routekey = "nr_test_q-array_headers-$unique";

my $dtag1=1;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0 }); };
is($@, '', "exchange_declare");
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, 'array_headers', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

my $payload = "Message payload";
my $headers = {
	nested_array_1 => [
		123,
		{
			"inner_hash_1" => "value"
		}
	],
	array_1 => [
		qw/
			array_1_a
			array_1_b
			array_1_c
		/
	],
	hash_1 => {
		hash_1_a => 1,
		hash_1_b => 2,
		hash_1_c => 3,
		hash_1_d => [
			qw/
				hash_1_d_a
				hash_1_d_b
				hash_1_d_c
			/
		],
		hash_1_e => {
			hash_1_e_f => 4,
			hash_1_e_g => 5
		}
	}
};

eval { $mq->publish(1, $routekey, $payload, { exchange => $exchange }, { headers => $headers }); };
is($@, '', "publish");
die "Fatal publish failure!" if $@;

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => $payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag1,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'headers' => $headers },
          }, "payload");

1;
