use Test::More tests => 21;
use strict;
use warnings;
use utf8;

use JSON;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $routekey = "nr_test_q-$unique";

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
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, '', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

my $utf8_payload = '{"message":"Mǎgìc Trañsiént Paylöàd"}';
ok(utf8::is_utf8($utf8_payload), 'message going in is utf8');
my $utf8_headers = { dummy => 'Sóme ŭtf8 strìng' };
ok(utf8::is_utf8($utf8_headers->{'dummy'}), 'header is utf8');
eval { JSON->new->decode($utf8_payload); };
is($@, '', "JSON decode");

eval { $mq->publish(1, $routekey, $utf8_payload, { exchange => $exchange }, { headers => $utf8_headers }); };
is($@, '', "publish");

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");
$rv->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($rv,
          {
          'body' => $utf8_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag1,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'headers' => $utf8_headers },
          }, "payload");

ok(utf8::is_utf8($rv->{'body'}), 'verify body back is utf8');
ok(utf8::is_utf8($rv->{'props'}->{'headers'}->{'dummy'}), 'verify dummy header back is utf8');
eval { JSON->new->decode($rv->{'body'}); };
is($@, '', "JSON decode again");

my $ascii_payload = "Some ASCII payload";

eval { $mq->publish(1, $routekey, $ascii_payload, { exchange => $exchange }, { content_encoding => 'C' }); };
is($@, '', "publish");

$rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");
$rv->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($rv,
          {
          'body' => $ascii_payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag2,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'content_encoding' => 'C' },
          }, "payload");
ok( ! utf8::is_utf8($rv->{'body'}), 'not utf8');

1;
