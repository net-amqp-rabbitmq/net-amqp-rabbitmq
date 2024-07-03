use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(3);

ok $helper->connect,      "connected";
ok $helper->channel_open, "channel_open";

ok $helper->basic_qos( { prefetch_count => 5 } ), "qos";
