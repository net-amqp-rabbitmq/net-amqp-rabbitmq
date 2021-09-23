use Test::More tests => 2;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

my $connection_options = $helper->get_connection_options();
my $client_properties = {
	connection_name => 'nar_test',
};

ok $helper->mq->connect($helper->{host}, $connection_options, $client_properties), 'connected';
my $test_client_properties = $helper->get_client_properties;
is $test_client_properties->{connection_name}, $client_properties->{connection_name},'connection_name set';
