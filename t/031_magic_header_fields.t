use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;
use Math::UInt64 qw/int64 uint64/;

my $helper = NAR::Helper->new;
$helper->plan(10);

ok $helper->connect,          "connected";
ok $helper->channel_open,     "channel_open";
ok $helper->exchange_declare, "default exchange declare";
ok $helper->queue_declare,    "queue declare";
ok $helper->queue_bind,       "queue bind";
ok $helper->drain,            "drain queue";

# create scalars of type PVMG
my ( $magic_int, $magic_float, $magic_string );
{
  local $/ = 3;
  $magic_int = $/;

  my $x = $1;

  local $/ = 1.2;
  $magic_float = $/;

  my $str = "abc12";
  $str =~ /^(.+)$/;
  $magic_string = $1;
}

my $payload = "Message payload";
my $headers = {
  int    => $magic_int,
  float  => $magic_float,
  string => $magic_string,
};

ok $helper->publish( $payload, { headers => $headers } ), "publish";
ok $helper->consume,                                      "consume";

my $rv = $helper->recv;
ok $rv, "recv";

is_deeply(
  $rv,
  {
    body         => $payload,
    channel      => 1,
    routing_key  => $helper->{routekey},
    delivery_tag => 1,
    redelivered  => 0,
    exchange     => $helper->{exchange},
    consumer_tag => 'ctag',
    props        => {
      'headers' => $headers,
    }
  },
  "payload"
);
