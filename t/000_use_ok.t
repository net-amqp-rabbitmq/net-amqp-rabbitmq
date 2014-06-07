use Test::More tests => 2;
use strict;
use warnings;

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);
