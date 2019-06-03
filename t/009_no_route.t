use Test::More tests => 5;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";

ok $helper->publish( "Magic Payload" ), "good publish";

my $props = {
    exchange  => $helper->{exchange},
    mandatory => 1,
    immediate => 1
};
ok $helper->publish( "Magic Payload", $props ), "bad publish";
