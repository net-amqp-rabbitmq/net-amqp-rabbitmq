use Test::More tests => 16;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

use Time::HiRes qw(gettimeofday tv_interval);

my $helper = NAR::Helper->new;

ok $helper->connect, "connected";
ok $helper->channel_open, "channel_open";

ok $helper->exchange_declare, "exchange declare";
ok $helper->queue_declare, "queue declare";
ok $helper->queue_bind, "queue bind";
ok $helper->drain, "drain queue";

my $props = {
        content_type     => 'text/plain',
        content_encoding => 'none',
        correlation_id   => '123',
        reply_to         => 'somequeue',
        expiration       => 60,
        message_id       => 'ABC',
        type             => 'notmytype',
        user_id          => $helper->{username},
        app_id           => 'idd',
        delivery_mode    => 1,
        priority         => 2,
        timestamp        => 1271857990,
    };
ok $helper->publish( "Magic Payload", $props ), "publish";

my $tag_back = $helper->consume;
is $helper->{consumer_tag}, $tag_back, 'consume returns the tag we gave it';

{
    local $SIG{ALRM} = sub { BAIL_OUT("timeout exceeded") };

    alarm 5;
    my $rv = $helper->recv(3000);
    alarm 0;

    is_deeply(
        $rv,
        {
            body         => 'Magic Payload',
            routing_key  => $helper->{routekey},
            delivery_tag => 1,
            redelivered  => 0,
            exchange     => $helper->{exchange},
            consumer_tag => $helper->{consumer_tag},
            props        => $props,
        },
        "payload matches"
    );
}

{
    my $start = [gettimeofday];

    local $SIG{ALRM} = sub { BAIL_OUT("timeout exceeded") };
    alarm 5;
    my $rv = $helper->mq->recv(1000);
    alarm 0;

    ok abs(tv_interval($start) - 1) < 0.01, "Timeout about 1 second";
    is $rv, undef, 'recv with timeout returns undef';
}

{
    my $start = [gettimeofday];

    local $SIG{ALRM} = sub { BAIL_OUT("timeout exceeded") };
    alarm 5;
    my $rv = $helper->mq->recv(1200);
    alarm 0;

    ok abs(tv_interval($start) - 1.2) < 0.01, "Timeout about 1.2 second";
    is $rv, undef, 'recv with timeout returns undef';
}

{
    my $start = [gettimeofday];

    local $SIG{ALRM} = sub { BAIL_OUT("timeout exceeded") };
    alarm 5;
    my $rv = $helper->mq->recv(-1);
    alarm 0;

    ok abs(tv_interval($start)) < 0.01, "Timeout about immediate";
    is $rv, undef, 'recv with timeout returns undef';
}

END {
    ok $helper->cleanup, "cleanup";
}
