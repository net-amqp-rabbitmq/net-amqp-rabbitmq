use Test::More tests => 7;
use strict;
use warnings;
use utf8;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;

my $delivery_tag = 1;

my $options = {
    passive     => 0,
    durable     => 1,
    exclusive   => 0,
    auto_delete => 1,
};

subtest "Initialization", sub {
    ok $helper->connect, "connected";
    ok $helper->channel_open, "channel_open";

    ok $helper->exchange_declare, "default exchange declare";

    my $queuename = $helper->queue_declare( $options, undef, 1 );
    isnt $queuename, '', "queue_declare -> private name";

    ok $helper->queue_bind( $queuename ), "queue bind";
    ok $helper->drain( $queuename ), "drain queue";

    ok $helper->consume( $queuename ), "consume";
};

subtest "Initialization", sub {
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
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { 'headers' => $utf8_headers },
        },
        "payload",
    );

    ok utf8::is_utf8($rv->{'body'}), 'verify body back is utf8';
    ok utf8::is_utf8($rv->{'props'}->{'headers'}->{'dummy'}), 'verify dummy header back is utf8';
};

my $ascii_payload = "Some ASCII payload";

subtest "Initialization", sub {

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
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
};

my $pub_props = { content_encoding => 'binary', headers => { "sample" => "sample" } };

subtest "Headers in UTF-8", sub {
# Now, don't go out of your way to set the headers to UTF-8, they should still
# come back as that.
    ok $helper->publish( $ascii_payload, $pub_props ), "publish";

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
            props        => $pub_props
        },
        "payload"
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
    ok !utf8::is_utf8( $rv->{'props'}->{"headers"}->{"sample"} ), 'is utf8';
};

subtest "force utf8 in header strings", sub {
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
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => $pub_props
        },
        "payload",
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
    ok utf8::is_utf8( $rv->{'props'}->{"headers"}->{"sample"} ), 'is utf8';
};

# See chamarreddy's sample_pack from
# Problem with Binary data · Issue #142
# https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/issues/142
my $int8_var=1;
my $int_var="200";
my $uint_var= "1234567890";
my $int64_var= "919404439788";
my $char_var1="First";
my $char_var2="Second";
my $packed_binary = pack( "c i I Q Z15 Z24", $int8_var,$int_var,$uint_var,$int64_var,$char_var1,$char_var2);

subtest "hand-packed binary blob works with content_encoding: 'binary'", sub {
    ok $helper->publish( $packed_binary, { content_encoding => 'binary' } ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    is_deeply(
        $rv,
        {
            body         => $packed_binary,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => { content_encoding => 'binary' },
        },
        "payload",
    );
    ok !utf8::is_utf8( $rv->{'body'} ), 'not utf8';
};

subtest "hand-packed binary blob doesn't work without content_encoding: 'binary'", sub {
    ok $helper->publish( $packed_binary ), "publish";

    my $rv = $helper->recv;
    ok $rv, "recv";

    my $body = delete $rv->{body};
    isnt($body, $packed_binary, 'body is no longer the $packed_binary');
    ok utf8::is_utf8( $body ), 'body marked as UTF-8 (although it almost clearly isn\'t valid UTF-8)';

    # The rest of $rv is as expected...
    is_deeply(
        $rv,
        {
            # body         => $packed_binary,
            channel      => 1,
            routing_key  => $helper->{routekey},
            delivery_tag => $delivery_tag++,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => 'ctag',
            props        => {},
        },
        "payload",
    );
};
