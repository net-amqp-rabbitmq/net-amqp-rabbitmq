use utf8;
use Test::More tests => 7;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";

my $queuename = undef;
my $message_count = 0;
my $consumer_count = 0;
( $queuename, $message_count, $consumer_count ) = $helper->queue_declare;

is $queuename, $helper->{queue}, "queue_declare";
is $message_count, 0, "0 messages in the queue";
is $consumer_count, 0, "0 consumers on the queue";

my $queue_options = {
    'x-dead-letter-exchange'    => 'amq.direct',
    'x-dead-letter-routing-key' => $helper->{routekey},
    'x-message-ttl'             => 10000,
    'x-expires'                 => 20000,
};
my $returned_queuename = $helper->queue_declare( {auto_delete => 1}, undef, 1, $queue_options );
ok $returned_queuename, "queue name";

END {
    note( "cleaning up" );

    $helper->purge;
    $helper->queue_unbind;
    $helper->queue_delete;
    $helper->queue_delete( $returned_queuename );
    $helper->exchange_delete;
    $helper->channel_close;
}
