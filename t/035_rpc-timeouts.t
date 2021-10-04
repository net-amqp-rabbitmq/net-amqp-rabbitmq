use Test::More tests => 17;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

my $mq = $helper->mq;

is $mq->get_rpc_timeout, undef, 'Default setting is undefined.';
is $mq->set_rpc_timeout( {tv_sec=> 10} ), undef, 'Setting the timeout to 10 seconds.';
is_deeply $mq->get_rpc_timeout, {tv_sec=>10, tv_usec=>0}, 'Making sure we get back what we sent in.';

is $mq->set_rpc_timeout( undef ), undef, 'Setting to unlimited.';
is_deeply $mq->get_rpc_timeout, undef, 'Making sure we get back what we sent in.';
# Repeat because we have a conditional to satisfy!
is $mq->set_rpc_timeout( undef ), undef, 'Setting to unlimited.';
is_deeply $mq->get_rpc_timeout, undef, 'Making sure we get back what we sent in.';

# Now with hashes
is $mq->set_rpc_timeout( tv_sec=> 10 ), undef, 'Setting the timeout to 10 seconds.';
is_deeply $mq->get_rpc_timeout, {tv_sec=>10, tv_usec=>0}, 'Making sure we get back what we sent in.';
is $mq->set_rpc_timeout( tv_usec=> 10 ), undef, 'Setting the timeout to 10 seconds.';
is_deeply $mq->get_rpc_timeout, {tv_sec=>0, tv_usec=>10}, 'Making sure we get back what we sent in.';

# Reset to nothing
is $mq->set_rpc_timeout( undef ), undef, 'Setting to unlimited.';
is_deeply $mq->get_rpc_timeout, undef, 'Making sure we get back what we sent in.';

is $mq->set_rpc_timeout( tv_usec=> 10 ), undef, 'Setting the timeout to 10 seconds.';
is_deeply $mq->get_rpc_timeout, {tv_sec=>0, tv_usec=>10}, 'Making sure we get back what we sent in.';
