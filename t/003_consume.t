use Test::More 0.88;
use strict;
use warnings;

use Sys::Hostname;
use Time::HiRes qw(gettimeofday tv_interval);

my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $queuename = "nr_test_hole-$unique";
my $routekey = "nr_test_route-$unique";

my $dtag=1;
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");

my $consumer_tag = 'ctag';
my $tag_back;
eval { $tag_back = $mq->consume(1, $queuename, {consumer_tag=>$consumer_tag, no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");
is($consumer_tag, $tag_back, 'consume returns the tag we gave it');

my $rv = {};
eval { local $SIG{ALRM} = sub {die}; alarm 5; $rv = $mq->recv(); alarm 0};
is($@, '', "recv");

is_deeply($rv,
          {
          'body' => 'Magic Payload',
          'routing_key' => $routekey,
          'delivery_tag' => $dtag,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => $consumer_tag,
          'props' => {
                content_type => 'text/plain',
                content_encoding => 'none',
                correlation_id => '123',
                reply_to => 'somequeue',
                expiration => 60 * 1000,
                message_id => 'ABC',
                type => 'notmytype',
                user_id => 'guest',
                app_id => 'idd',
                delivery_mode => 1,
                priority => 2,
                timestamp => 1271857990,
            },
          }, "payload");

my $start;

$start = [gettimeofday];
eval { local $SIG{ALRM} = sub {die}; alarm 5; $rv = $mq->recv(1000); alarm 0};
ok(abs(tv_interval($start) - 1) < 0.01, "Timeout about 1 second");
is($@, '', 'recv with timeout');
is($rv, undef, 'recv with timeout returns undef');

$start = [gettimeofday];
eval { local $SIG{ALRM} = sub {die}; alarm 5; $rv = $mq->recv(1200); alarm 0};
ok(abs(tv_interval($start) - 1.2) < 0.01, "Timeout about 1.2 second");
is($@, '', 'recv with timeout');
is($rv, undef, 'recv with timeout returns undef');

$start = [gettimeofday];
eval { local $SIG{ALRM} = sub {die}; alarm 5; $rv = $mq->recv(-1); alarm 0};
ok(abs(tv_interval($start)) < 0.01, "Timeout about immediate");
is($@, '', 'immediate recv');
is($rv, undef, 'immediate recv returns undef');

eval { $mq->cancel(1, $consumer_tag); };
is($@, '', 'cancel');

done_testing;
