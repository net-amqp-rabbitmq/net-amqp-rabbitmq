use Test::More tests => 2;
use strict;
use warnings;

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
my $lives = 0;
eval { $mq->channel_close(1); $lives = 1; };

is( $lives, 1, 'dead channel_close()');
