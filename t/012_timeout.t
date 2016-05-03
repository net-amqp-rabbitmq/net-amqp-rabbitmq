use strict;
use warnings;
use Test::More tests => 2;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;
use Time::HiRes qw/gettimeofday tv_interval/;

if ( $ENV{MQSSL} ) {
    $ENV{MQSSLHOST} = '199.15.224.0'; #This OmniTI IP will hang
}
else {
    $ENV{MQHOST} = '199.15.224.0'; #This OmniTI IP will hang
}
my $helper = NAR::Helper->new;

$SIG{'PIPE'} = 'IGNORE';

my $start = [gettimeofday];
my $timeout = 3;

ok !$helper->connect( undef, $timeout ), "not connected";
my $duration = tv_interval($start);
# 500ms tolerance should work with most operating systems
cmp_ok(abs($duration-$timeout), '<', 0.5, 'timeout');
