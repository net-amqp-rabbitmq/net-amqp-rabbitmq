use Test::More tests => 11;
use strict;
use warnings;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");


# Verify we enforce server_properties connection requirement
eval { my $results = $mq->get_server_properties(); };
like( $@, qr/AMQP socket not connected/, "no socket, no get_server_properties" );

# Verify we enforce client_properties connection requirement
eval { my $results = $mq->get_client_properties(); };
like( $@, qr/AMQP socket not connected/, "no socket, no get_client_properties" );

# Now connect
eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

# Now verify server properties
my $server_properties = undef;
eval { $server_properties = $mq->get_server_properties(); };
is($@, '', "get_server_properties");

ok(exists( $server_properties->{product} ), 'product should be returned');
is($server_properties->{'product'}, 'RabbitMQ', 'product is RabbitMQ');

# Now verify client properties
my $client_properties = undef;
eval { $client_properties = $mq->get_client_properties(); };
is($@, '', "get_server_properties");
ok(exists( $client_properties->{product} ), 'product should be returned');
is($client_properties->{'product'}, 'rabbitmq-c', 'product is rabbitmq-c');

1;

