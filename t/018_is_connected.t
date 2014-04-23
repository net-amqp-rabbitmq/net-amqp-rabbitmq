use Test::More tests => 6;
use strict;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is( $mq->is_connected(), 1, 'Verify that we detected a connection...' );
is($@, '', "connect");
eval { $mq->disconnect(); };
is($@, '', "disconnect");
is( $mq->is_connected(), undef, 'Verify that we detected a NO connection following disconnect...' );

1;
