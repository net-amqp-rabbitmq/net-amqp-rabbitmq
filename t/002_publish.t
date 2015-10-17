use Test::More tests => 13;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $queuename = "nr_test_hole-$unique";
my $routekey = "nr_test_route-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");

# Re-establish the exchange if it wasn't created in 001
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 0 }); };
is($@, '', "exchange_declare");

# Declare the queue and bind
eval { $mq->queue_declare(1, $queuename, { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");
eval { 1 while($mq->get(1, $queuename)); };
is($@, '', "drain queue");
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


# Clean up
eval { 1 while($mq->purge(1, $queuename)); };
is($@, '', "purge queue");

eval { $mq->queue_unbind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_unbind");

eval { $mq->queue_delete(1, $queuename); };
is($@, '', "queue_delete");

eval { $mq->exchange_delete(1, $exchange); };
is($@, '', "exchange_delete");

1;
