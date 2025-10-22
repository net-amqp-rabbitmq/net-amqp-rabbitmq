use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(11);

ok $helper->connect,      "connected";
ok $helper->channel_open, "channel_open";
my %exchange_options = (
  passive     => 0,
  durable     => 1,
  auto_delete => 0,
);
ok(
  $helper->exchange_declare(
    {
      exchange_type => "fanout",
      %exchange_options
    },
    'ae'
  ),
  "ae exchange declare"
);
my $ae_exchange = $helper->{exchange} . 'ae';
ok(
  $helper->exchange_declare(
    {
      exchange_type => "direct",
      %exchange_options
    },
    undef,
    {
      "alternate-exchange" => $ae_exchange,
    }
  ),
  'declare main exchange'
);

ok $helper->queue_declare,                     "queue declare";
ok $helper->queue_bind( undef, $ae_exchange ), "queue bind";
ok $helper->drain,                             "drain queue";

ok $helper->publish("Magic Payload"), "publish";

my $getr = $helper->get;
ok $getr, "get";

is $getr->{'body'}, "Magic Payload", "Verify payload is the same";
is $getr->{'exchange'}, $helper->{exchange},
  "Verify it was indeed sent to the original exchange";
