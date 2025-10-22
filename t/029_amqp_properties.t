use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(7);

ok $helper->connect, "connected";

my $server_properties = $helper->get_server_properties;
ok $server_properties, "get_server_properties";

ok exists( $server_properties->{product} ), 'product should be returned';
is $server_properties->{'product'}, 'RabbitMQ', 'product is RabbitMQ';

# Now verify client properties
my $client_properties = $helper->get_client_properties;
ok $client_properties,                      "get_client_properties";
ok exists( $client_properties->{product} ), 'product should be returned';
is $client_properties->{'product'}, 'rabbitmq-c', 'product is rabbitmq-c';
