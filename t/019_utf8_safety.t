use Test::More tests => 29;
use strict;
use warnings;
use utf8;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "default exchange declare";

my $dtag1=1;
my $dtag2=2;
my $dtag3=3;
my $dtag4=4;

my $options = {
    passive     => 0,
    durable     => 1,
    exclusive   => 0,
    auto_delete => 1,
};
my $queuename = $helper->queue_declare( $options, undef, 1 );
isnt $queuename, '', "queue_declare -> private name";

ok $helper->queue_bind( $queuename ), "queue bind";
ok $helper->drain( $queuename ), "drain queue";

ok $helper->consume( $queuename ), "consume";

{
    my $utf8_payload = "Mǎgìc Trañsiént Paylöàd";
    ok utf8::is_utf8($utf8_payload), 'message going in is utf8';

    my $utf8_headers = {
        dummy => 'Sóme ŭtf8 strìng',
    };
    ok utf8::is_utf8($utf8_headers->{'dummy'}), 'header is utf8';

    ok $helper->publish( $utf8_payload, { headers => $utf8_headers } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $utf8_payload,
            routing_key  => $helper->{routekey},
            delivery_tag => $dtag1,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'headers' => $utf8_headers },
        },
        "payload",
    );

    ok utf8::is_utf8($rv->{'body'}), 'verify body back is utf8';
    ok utf8::is_utf8($rv->{'props'}->{'headers'}->{'dummy'}), 'verify dummy header back is utf8';
}

my $ascii_payload = "Some ASCII payload";

{
    ok $helper->publish( $ascii_payload, { content_encoding => 'C' } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $ascii_payload,
            routing_key  => $helper->{routekey},
            delivery_tag => $dtag2,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'content_encoding' => 'C' },
        },
        "payload"
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
}

my $pub_props = { content_encoding => 'C', headers => { "sample" => "sample" } };
{
# Now, don't go out of your way to set the headers to UTF-8, they should still
# come back as that.
    ok $helper->publish( $ascii_payload, $pub_props ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $ascii_payload,
            routing_key  => $helper->{routekey},
            delivery_tag => $dtag3,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => $pub_props
        },
        "payload"
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
    ok !utf8::is_utf8( $rv->{'props'}->{"headers"}->{"sample"} ), 'is utf8';
}

#force utf8 in header strings
{
    my $options = {
        exchange                     => $helper->{exchange},
        force_utf8_in_header_strings => 1,
    };

    ok $helper->publish( $ascii_payload, $pub_props, undef, $options ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $ascii_payload,
            routing_key  => $helper->{routekey},
            delivery_tag => $dtag4,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => $pub_props
        },
        "payload",
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
    ok utf8::is_utf8( $rv->{'props'}->{"headers"}->{"sample"} ), 'is utf8';
}

END {
    ok $helper->cleanup( $queuename ), "cleanup";
}
