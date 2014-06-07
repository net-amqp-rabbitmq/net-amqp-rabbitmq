use Test::More tests => 6;
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
my $result = $mq->connect($host, {"user" => "guest", "password" => "guest"});
ok($result, 'connect');
eval { $mq->channel_open(1); };

is($@, '', 'channel_open');
eval { $mq->publish(1, $routekey, "Magic Payload",
                       { exchange => $exchange }); };
is($@, '', 'good pub');
eval { $mq->publish(1, $routekey, "Magic Payload",
                       { exchange => $exchange,
                         'mandatory' => 1, 'immediate' => 1}); };
is($@, '', 'bad pub');
$mq->disconnect();
