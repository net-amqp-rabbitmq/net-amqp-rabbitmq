use Test::More tests => 27;
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

# Re-establish the exchange if it wasn't created in 001
# or in 002
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 0 }); };
is($@, '', "exchange_declare");

# Re-establish the queue if it wasn't made in test 002
eval { $mq->queue_declare(1, $queuename, { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

# We want to drain the queue first...
eval { 1 while($mq->purge(1, $queuename)); };
is($@, '', "purge queue");

# We want this test to be self-contained, so we need
# to publish ourselves.
eval { $mq->publish(1, $routekey, "Magic Payload", 
                       { exchange => $exchange },
                       {
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
                   ); };
is($@, '', "publish");

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


# Clean up
eval { $mq->cancel(1, $consumer_tag); };
is($@, '', 'cancel');

eval { 1 while($mq->purge(1, $queuename)); };
is($@, '', "purge queue");

eval { $mq->queue_unbind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_unbind");

eval { $mq->queue_delete(1, $queuename); };
is($@, '', "queue_delete");

eval { $mq->exchange_delete(1, $exchange); };
is($@, '', "exchange_delete");

1;