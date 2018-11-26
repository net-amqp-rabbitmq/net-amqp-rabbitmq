use Test::More tests => 19;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";
ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

my $tag_back = $helper->consume;
is $helper->{consumer_tag}, $tag_back, 'consume returns the tag we gave it';

#we don't need to publish or anything, as the segfault happens either way
my $rv = $helper->recv(-1);
$helper->ack( 1231211 );

#cancel will fail because the above ack caused an error
# this used to cause a segfault. but now it shouldn't
is $helper->cancel, undef, 'cancel fails';
is $rv, undef, "recv";

ok $helper->disconnect, 'disconnect';

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

$tag_back = $helper->consume;
is $helper->{consumer_tag}, $tag_back, 'consume returns the tag we gave it';

#this one shouldn't fail or segfault
ok $helper->cancel( $tag_back ), 'cancel ok';
ok $helper->disconnect, 'disconnect';
ok !$helper->cancel, "cancel on disconnected fails";

END {
    ok $helper->cleanup, "cleanup";
}
