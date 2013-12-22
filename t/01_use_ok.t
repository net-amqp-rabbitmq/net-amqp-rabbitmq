use Test::More tests => 2;
use strict;
use warnings;

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

#there are more tests in xt, but we don't run them because currently dev.rabbitmq.com is down :(
