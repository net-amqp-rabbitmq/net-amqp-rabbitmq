use Test::More tests => 1;
use strict;
use warnings;

my $ok;
END { BAIL_OUT "Could not load all modules" unless $ok }
use Net::AMQP::RabbitMQ;
ok 1, 'All modules loaded successfully';
$ok = 1;
