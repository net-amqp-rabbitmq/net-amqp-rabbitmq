use Test::More tests => 29;
use strict;
use warnings;
use utf8;

use Math::UInt64 qw/uint64/;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $routekey = "nr_test_q-$unique";

my $dtag1=1;
my $dtag2=2;
my $dtag3=3;
my $dtag4=4;
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, '', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

my $utf8_payload = "Mǎgìc Trañsiént Paylöàd";
ok(utf8::is_utf8($utf8_payload), 'message going in is utf8');
my $utf8_headers = { dummy => 'Sóme ŭtf8 strìng' };
ok(utf8::is_utf8($utf8_headers->{'dummy'}), 'header is utf8');

eval { $mq->publish(1, $routekey, $utf8_payload, { exchange => $exchange }, { headers => $utf8_headers }); };
is($@, '', "publish");

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => $utf8_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag1,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'headers' => $utf8_headers },
          }, "payload");

ok(utf8::is_utf8($rv->{'body'}), 'verify body back is utf8');
ok(utf8::is_utf8($rv->{'props'}->{'headers'}->{'dummy'}), 'verify dummy header back is utf8');

my $ascii_payload = "Some ASCII payload";

eval { $mq->publish(1, $routekey, $ascii_payload, { exchange => $exchange }, { content_encoding => 'C' }); };
is($@, '', "publish");

$rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => $ascii_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag2,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'content_encoding' => 'C' },
          }, "payload");
ok( ! utf8::is_utf8($rv->{'body'}), 'not utf8');

my $pub_props = { content_encoding => 'C', headers => { "sample" => "sample" } };
# Now, don't go out of your way to set the headers to UTF-8, they should still
# come back as that.
eval {
     $mq->publish(
          1,
          $routekey,
          $ascii_payload,
          { exchange => $exchange },
          $pub_props
     );
};
is($@, '', "publish");

$rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => $ascii_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag3,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => $pub_props
          }, "payload");
ok( ! utf8::is_utf8($rv->{'body'}), 'not utf8');
ok( ! utf8::is_utf8($rv->{'props'}->{"headers"}->{"sample"}), 'is utf8');

# Now, don't go out of your way to set the headers to UTF-8, they should still
# come back as that.
eval {
     $mq->publish(
          1,
          $routekey,
          $ascii_payload,
          { exchange => $exchange, force_utf8_in_header_strings => 1 },
          $pub_props
     );
};
is($@, '', "publish");

$rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => $ascii_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag4,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => $pub_props
          }, "payload");
ok( ! utf8::is_utf8($rv->{'body'}), 'not utf8');
ok( utf8::is_utf8($rv->{'props'}->{"headers"}->{"sample"}), 'is utf8');

1;
