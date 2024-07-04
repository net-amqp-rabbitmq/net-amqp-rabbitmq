use Test::More tests => 1;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

# This test is fine without connectivity.

my $helper = NAR::Helper->new;

ok $helper->channel_close, "dead channel_close";
