use Test::More tests => 5;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

# USING THE SOCKET IS LIKELY TO BREAK, YOU HAVE BEEN WARNED

# Make sure trying to get a sock descriptor prior to connection is undef
is(
    $helper->mq->get_sockfd,
    undef,
    'getting sock prior to connection yields undef'
);

ok $helper->connect, "connected";

# Make sure we can get a sock descriptor now
cmp_ok(
    $helper->mq->get_sockfd,
    '>',
    2, # 2 is STDERR
    'should have a valid sockfd'
);

ok $helper->channel_open, "channel_open";

is(
    $helper->mq->get_channel_max,
    65535,
    'max channel is 65535, per documentation of librabbitmq'
);
