use Test::More;
use strict;
use warnings;

use Sys::Hostname;

if (!eval q{ use LWP::UserAgent; 1 }) {
    plan skip_all => 'LWP::UserAgent not available';
}
if (defined $ENV{'MQHOST'} && $ENV{'MQHOST'} ne 'dev.rabbitmq.com') {
    # XXX Exact API URL and port may differ on other hosts, so
    #     allow only dev.rabbitmq.com.
    plan skip_all => 'Works only against dev.rabbitmq.com';
}
plan tests => 15;

my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-boolean_header_fields-$unique";
my $routekey = "nr_test_q-boolean_header_fields-$unique";

my @dtags=( 1, 2 );
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "fanout", passive => 0, durable => 1, auto_delete => 1 }); };
is($@, '', "exchange_declare");
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, 'nr_test_q-boolean_header_fields', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

# XXX Temporarily use LWP::UserAgent to inject boolean values.
#     This might be rewritten once it's possible to publish
#     boolean values with Net::AMQP::RabbitMQ itself.
my $ua = LWP::UserAgent->new;

for my $test_def (['true', 1], ['false', 0]) {
    my($boolean_value, $perl_value) = @$test_def;
    my $resp = $ua->post("http://guest:guest\@$host/mgmt/api/exchanges/%2F/$exchange/publish", Content => <<"EOF");
{"properties":{"headers":{"booltest":$boolean_value}},"routing_key":"$routekey","payload":"test boolean","payload_encoding":"string"}
EOF
    ok $resp->is_success, "Publishing message with boolean value $boolean_value"
	or diag "Publishing booltest message failed: " . $resp->as_string;

    my $rv = {};
    eval { $rv = $mq->recv(); };
    is($@, '', "recv");
    my $expected_dtag = shift @dtags;
    is_deeply($rv,
	      {
	       'body' => 'test boolean',
	       'routing_key' => $routekey,
	       'delivery_tag' => $expected_dtag,
	       'redelivered' => 0,
	       'exchange' => $exchange,
	       'consumer_tag' => 'ctag',
	       'props' => { 'headers' => { 'booltest' => $perl_value } },
	      }, "payload and header with boolean value $boolean_value");
}

1;
