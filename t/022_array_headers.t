use Test::More tests => 12;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-array_headers-$unique";
my $routekey = "nr_test_q-array_headers-$unique";

my $dtag1=(unpack("L",pack("N",1)) != 1)?'0100000000000000':'0000000000000001';
my $dtag2=(unpack("L",pack("N",1)) != 1)?'0200000000000000':'0000000000000002';
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
my $headers = { array_1 => [qw/a b c/], hash_1 => { a => 1, b => 2, c => 3, d => [qw/a b c/], e => { f => 4, g => 5 } } };

eval { $mq->publish(1, $routekey, $payload, { exchange => $exchange }, { headers => $headers }); };
is($@, '', "publish");
die "Fatal publish failure!" if $@;

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");
$rv->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($rv,
          {
          'body' => $payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag1,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'headers' => $headers },
          }, "payload");

done_testing();

1;
