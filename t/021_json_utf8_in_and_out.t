use strict;
use warnings;
use Test::More;
use utf8;

my $has_json = eval("use JSON; 1");
if ( $@ ) {
     plan skip_all => "Missing JSON.pm";
} else {
     plan tests => 21;
}

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

ok $helper->consume, "consume";

my $utf8_payload = '{"message":"Mǎgìc Trañsiént Paylöàd"}';
ok utf8::is_utf8($utf8_payload), 'message going in is utf8';
my $utf8_headers = {
    dummy => 'Sóme ŭtf8 strìng'
};
ok utf8::is_utf8($utf8_headers->{'dummy'}), 'header is utf8';
ok from_json( $utf8_payload ), "utf8_payload is valid json";

{
    ok $helper->publish( $utf8_payload, { headers => $utf8_headers } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $utf8_payload,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => 1,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'headers' => $utf8_headers },
        },
        "payload"
    );

    ok utf8::is_utf8($rv->{'body'}), 'verify body back is utf8';
    ok utf8::is_utf8($rv->{'props'}->{'headers'}->{'dummy'}), 'verify dummy header back is utf8';

    ok from_json( $rv->{body} ), "rv body is valid json";
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
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => 2,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'content_encoding' => 'C' },
        },
        "payload"
    );
    ok( !utf8::is_utf8( $rv->{'body'} ), 'not utf8' );
}

END {
    if ($has_json) {
        ok $helper->cleanup, "cleanup";
    }
}
