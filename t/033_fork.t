use Test::More tests => 3;
use strict;
use warnings;

# When we fork below, if the child closes the parent's connection the parent
# will sit around for 30 seconds before declaring an error.
# This tests:
# REQUEST: optionally leave connection alive in net_amqp_rabbitmq_DESTROY to
# allow forking · Issue #151
# https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/issues/151

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

my $max_run_seconds = 10;

my $pid = fork;
die "fork failed"
    unless defined $pid;

# just exit from the child - test that this doesn't close the connection that
# the parent opened.
exit
    unless $pid;

# Make sure the child has had a chance to exit (and close the connection if
# #151 is still valid) before continuing
waitpid($pid, 0);

ok $helper->exchange_declare, "default exchange declare";
