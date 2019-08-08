use strict;
use warnings;
use Test::More;
use utf8;
use Encode;

my $has_json = eval("use JSON; 1");
if ( $@ ) {
     plan skip_all => "Missing JSON.pm";
} else {
     plan tests => 6;
}

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

# About the difference between JSON's encode_json and to_json:
#
# $json_text = encode_json $perl_scalar
#     is equivalent to:
# $json_text = JSON->new->utf8->encode($perl_scalar)
#
# It returns a binary string (without the UTF-8 flag set).
#
# $json_text = to_json($perl_scalar)
#     is equivalent to:
# $json_text = JSON->new->encode($perl_scalar)
#
# It returns a UTF-8 encoded string (with the UTF-8 flag set).
#
# So:
#
# encode_json($perl_scalar) eq Encode::encode_utf8(to_json($perl_scalar))
#
# The JSON documentation prefers encode_json over to_json throughout (except to
# document to_json itself)
#
# And for completeness, decode_json is the opposite of encode_json and
# from_json is the opposite of to_json. So they come as pairs: (encode_json,
# decode_json) and (to_json, from_json).

my $helper = NAR::Helper->new;

subtest "initialization", sub {
    ok $helper->connect, "connected";
    ok $helper->channel_open, "channel_open";
    ok $helper->exchange_declare, "default exchange declare";
    ok $helper->queue_declare, "queue declare";
    ok $helper->queue_bind, "queue bind";
    ok $helper->drain, "drain queue";

    ok $helper->consume, "consume";
};

my $delivery_tag = 1;

# here we test JSON using UTF-8 characters (not octets) using encode_json/decode_json
my $utf8_payload_octets = encode_json({"message" => "Mǎgìc Trañsiént Paylöàd"});
ok ! utf8::is_utf8($utf8_payload_octets), 'message going in is not utf8';

subtest "UTF-8 binary string works with content_encoding: binary", sub {
    ok $helper->publish( $utf8_payload_octets, { content_encoding => 'binary' } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $utf8_payload_octets,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'content_encoding' => 'binary' },
        },
        "payload"
    );

    ok ! utf8::is_utf8($rv->{'body'}), 'verify body back is not utf8 flagged';

    ok decode_json( $rv->{body} ), "rv body is valid json";
};

subtest "UTF-8 binary string doesn't work without content_encoding (need to manualy decode_utf8)", sub {
    # Note how this test doesn't give you back the data that got published...
    ok $helper->publish( $utf8_payload_octets ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            # Notice how we have to decode here to get at the original octets
            # (it does decode properly, though)
            body         => Encode::decode('UTF-8', $utf8_payload_octets, Encode::FB_CROAK),
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => {},
        },
        "payload"
    );

    ok utf8::is_utf8($rv->{'body'}), 'verify body back is utf8 flagged';

    # Note that this is from_json, not decode_json. The lack of
    # content_encoding => 'binary' causes it to be decoded as UTF-8.
    ok from_json( $rv->{body} ), "rv body is valid, UTF-8 encoded json";
};

# here we test JSON using UTF-8 characters (not octets) using to_json/from_json
subtest "UTF-8 encoded string - without content_encoding", sub {
    my $utf8_payload = to_json({"message" => "Mǎgìc Trañsiént Paylöàd"});
    ok utf8::is_utf8($utf8_payload), 'message going in is utf8';
    my $utf8_headers = {
        dummy => 'Sóme ŭtf8 strìng'
    };
    ok utf8::is_utf8($utf8_headers->{'dummy'}), 'header is utf8';
    ok from_json( $utf8_payload ), "utf8_payload is valid json";

    ok $helper->publish( $utf8_payload, { headers => $utf8_headers } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $utf8_payload,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
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
};

subtest "ASCII payload with content_encoding: binary", sub {
    my $ascii_payload = "Some ASCII payload";
    ok $helper->publish( $ascii_payload, { content_encoding => 'binary' } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $ascii_payload,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'content_encoding' => 'binary' },
        },
        "payload"
    );
    ok( !utf8::is_utf8( $rv->{'body'} ), 'not utf8' );
};
