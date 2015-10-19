use Test::More tests => 22;
use strict;
use warnings;

use Math::UInt64 qw/uint64/;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V-$$"; #hostname-os-perlversion-PID
my $exchange = "nr_test_x-$unique";
my $routekey = "nr_test_q-$unique";

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

my $queuename = '';
eval { $queuename = $mq->queue_declare(1, '', { passive => 0, durable => 0, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

my $getr;
eval { $getr = $mq->get(1, $queuename); };
is($@, '', "get");
is($getr, undef, "get should return empty");

eval { $mq->publish(1, $routekey, "Magic Transient Payload", { exchange => $exchange }); };

eval { $getr = $mq->get(1, $queuename, {no_ack=>0}); };
is($@, '', "get");

is_deeply($getr,
          {
            redelivered => 0,
            routing_key => $routekey,
            exchange => $exchange,
            message_count => 0,
            delivery_tag => $dtag,
            'props' => {},
            body => 'Magic Transient Payload',
          }, "get should see message");

# Let's close the channel, forcing the unacknowledged message to be re-delivered.
eval { $mq->channel_close(1); };
is($@, '', "channel_close");
eval { $mq->channel_open(1); };
is($@, '', "channel_open again");

# Get the message again and prove it was redelivered
eval { $getr = $mq->get(1, $queuename, {no_ack=>1}); };
is($@, '', "get");

is_deeply($getr,
          {
            redelivered => 1,
            routing_key => $routekey,
            exchange => $exchange,
            message_count => 0,
            delivery_tag => $dtag,
            'props' => {},
            body => 'Magic Transient Payload',
          }, "get should see redelivered message");

eval { $mq->publish(1, $routekey, "Magic Transient Payload 2", 
                     { exchange => $exchange }, 
                     {
                       content_type => 'text/plain',
                       content_encoding => 'none',
                       correlation_id => '123',
                       reply_to => 'somequeue',
                       expiration => 1000,
                       message_id => 'ABC',
                       type => 'notmytype',
                       user_id => 'guest',
                       app_id => 'idd',
                       delivery_mode => 1,
                       priority => 2,
                       timestamp => 1271857990,
                     },
                     ); };

eval { $getr = $mq->get(1, $queuename); };
is($@, '', "get");

$dtag =~ s/1/2/;
is_deeply($getr,
          {
            redelivered => 0,
            routing_key => $routekey,
            exchange => $exchange,
            message_count => 0,
            delivery_tag => $dtag,
            props => {
                content_type => 'text/plain',
                content_encoding => 'none',
                correlation_id => '123',
                reply_to => 'somequeue',
                expiration => 1000,
                message_id => 'ABC',
                type => 'notmytype',
                user_id => 'guest',
                app_id => 'idd',
                delivery_mode => 1,
                priority => 2,
                timestamp => 1271857990,
            },
            body => 'Magic Transient Payload 2',
          }, "get should see message");

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