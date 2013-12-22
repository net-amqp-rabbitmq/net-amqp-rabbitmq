use Test::More tests => 8;
use strict;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->queue_declare(1, "nr_test_hole", { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");
eval { $mq->queue_bind(1, "nr_test_hole", "nr_test_x", "nr_test_route"); };
is($@, '', "queue_bind");
eval { 1 while($mq->get(1, "nr_test_hole")); };
is($@, '', "drain queue");
eval { $mq->publish(1, "nr_test_route", "Magic Payload", 
                       { exchange => "nr_test_x" },
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

1;
