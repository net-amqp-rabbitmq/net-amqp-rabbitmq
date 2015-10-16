use Test::More tests => 18;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "x-nr_test_x-$unique";
my $routekey = "nr_test_route-$unique";

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");

eval { my $tag_back = $mq->channel_open(1); };
like( $@, qr/AMQP socket not connected/, "no socket, no channel_open" );

eval { my $tag_back = $mq->channel_close(1); };
is( $@, q//, "no socket, nothing at all from channel_close" );

eval { my $tag_back = $mq->exchange_declare( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no exchange_declare" );

eval { my $tag_back = $mq->exchange_delete( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no exchange_delete" );

eval { my $tag_back = $mq->queue_declare( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no queue_declare" );

eval { my $tag_back = $mq->queue_delete( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no queue_delete" );

eval { my $tag_back = $mq->queue_bind( 1, "dummy", "dummy", "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no queue_bind" );

eval { my $tag_back = $mq->queue_unbind( 1, "dummy", "dummy", "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no queue_unbind" );

eval { my $tag_back = $mq->consume( 1, "dummy", {} ); };
like( $@, qr/AMQP socket not connected/, "no socket, no consume" );

eval { my $tag_back = $mq->recv(); };
like( $@, qr/AMQP socket not connected/, "no socket, no recv" );

eval { my $tag_back = $mq->ack( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no ack" );

eval { my $tag_back = $mq->reject( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no reject" );

eval { my $tag_back = $mq->cancel(1, "foo"); };
like( $@, qr/AMQP socket not connected/, "no socket, no cancel" );

eval { my $tag_back = $mq->purge( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no purge" );

eval { my $tag_back = $mq->publish( 1, "dummy", "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no publish" );

eval { my $tag_back = $mq->get( 1, "dummy" ); };
like( $@, qr/AMQP socket not connected/, "no socket, no get" );
