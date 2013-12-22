use Test::More tests => 6;
use strict;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);
my $result = $mq->connect($host, {"user" => "guest", "password" => "guest"});
ok($result, 'connect');
eval { $mq->channel_open(1); };

is($@, '', 'channel_open');
eval { $mq->publish(1, "nr_test_route", "Magic Payload",
                       { exchange => "nr_test_x" }); };
is($@, '', 'good pub');
eval { $mq->publish(1, "nr_test_route", "Magic Payload",
                       { exchange => "nr_test_x",
                         'mandatory' => 1, 'immediate' => 1}); };
is($@, '', 'bad pub');
$mq->disconnect();
