use Test::More tests => 18;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;
use NAR::Blessed;

use Time::HiRes qw(gettimeofday tv_interval);

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";
{
    my $headers = {
        abc => 123,
        def => 'xyx',
        head3 => 3,
        head4 => 4,
        head5 => 5,
        head6 => 6,
        head7 => 7,
        head8 => 8,
        head9 => 9,
        head10 => 10,
        head11 => 11,
        head12 => 12,
    };

    ok $helper->publish( "Header Test", {headers => $headers } ), "publish";

    ok $helper->consume, "consume";

    my $msg = $helper->recv;
    ok $msg, "recv";

    is( $msg->{body}, 'Header Test', "Received body" );
    is( exists $msg->{props}, 1, "Props exist" );
    is( exists $msg->{props}{headers}, 1, "Headers exist" );
    is_deeply( $msg->{props}{headers}, $headers, "Received headers" );
}

{
    my $headers = {
        blah   => NAR::Blessed->new('foo'),
        array  => [1..100],
        hash   => {
            foo       => 'bar',
            something => 1234,
            another   => [qw/bacon double cheese burger please/, {test => 123, testing => 'testing'}],
        }
    };
    ok $helper->publish( "Header Test", {headers => $headers } ), "publish with blessed header values";

    my $msg = $helper->recv;
    ok $msg, "recv from blessed header values";

    is_deeply( $msg->{props}->{headers}, $headers, "Received blessed headers" );
    is $msg->{props}->{headers}->{blah}, "" . $headers->{blah}, 'overload still works';
}

END {
    ok $helper->cleanup, "cleanup";
}
