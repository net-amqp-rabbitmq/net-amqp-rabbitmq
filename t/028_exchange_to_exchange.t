use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(18);

ok $helper->connect,      "connected";
ok $helper->channel_open, "channel_open";

my %exchange_options = (
  passive     => 0,
  durable     => 0,
  auto_delete => 1
);
ok $helper->exchange_declare(
  { exchange_type => 'direct', %exchange_options }, 'a'
  ),
  "exchange declare a";
ok $helper->exchange_declare(
  { exchange_type => 'fanout', %exchange_options }, 'b'
  ),
  "exchange declare b";
my $exchangeA = $helper->{exchange} . 'a';
my $exchangeB = $helper->{exchange} . 'b';

ok $helper->queue_declare, "queue declare";
ok $helper->exchange_bind( $exchangeB, $exchangeA, { nothing => "nothing" } ),
  "exchange_bind";
ok $helper->queue_bind( undef, $exchangeB ), "queue bind";
ok $helper->drain,                           "drain queue";

ok $helper->publish( "e2e testing", undef, undef, { exchange => $exchangeA } ),
  "publish";

ok $helper->consume, "consume";

my $rv = $helper->recv;
ok $rv, "recv";
is $rv->{body}, 'e2e testing', 'verify body matches';

ok $helper->exchange_unbind( $exchangeB, $exchangeA, { nothing => "nothing" } ),
  "exchange_unbind";
ok $helper->queue_unbind( undef, $exchangeB ), "queue_unbind";

# Test parameter validation!
my $empty_value = "";
eval {
  $helper->mq->exchange_bind( $helper->{channel}, $empty_value, $exchangeA,
    $helper->{routekey} );
};
like(
  $@,
  qr/source and destination must both be specified/,
  "Binding exchange-to-exchange without a destination name"
);
eval {
  $helper->mq->exchange_bind( $helper->{channel}, $exchangeB, $empty_value,
    $helper->{routekey} );
};
like(
  $@,
  qr/source and destination must both be specified/,
  "Binding exchange-to-exchange without a source name"
);

# Now for unbinding
eval {
  $helper->mq->exchange_unbind( $helper->{channel}, $empty_value, $exchangeA,
    $helper->{routekey} );
};
like(
  $@,
  qr/source and destination must both be specified/,
  "Unbinding exchange-to-exchange without a destination name"
);
eval {
  $helper->mq->exchange_unbind( $helper->{channel}, $exchangeB, $empty_value,
    $helper->{routekey} );
};
like(
  $@,
  qr/source and destination must both be specified/,
  "Unbinding exchange-to-exchange without a source name"
);
