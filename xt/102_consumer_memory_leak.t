use strict;
use warnings;

use Net::AMQP::RabbitMQ;
use Test::More tests => 11;
use Sys::Hostname;

my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-$unique";
my $routekey = "nr_test_q-$unique";

my $host = $ENV{'MQHOST'} || die "you must set MQHOST to run this test";
diag "this test is slow, and probably only works on linux";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, '', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 0 }); };
is($@, '', "exchange_declare");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");
$mq->publish(1, $routekey, "They Live (CONSUME)", { exchange => $exchange });
is($@, '', "publish_initial_message");
$mq->consume(1, $queuename);
is($@, '', "consume");

my $i = 0;
my $start_mem = get_mem();
while ( $i < 100_000 ) {
    my $msg = $mq->recv();
    $msg = $msg->{body};
    $mq->publish(1, $routekey, $msg, { exchange => $exchange });
    if ( ( $i % 10_000 ) == 0 ) {
        diag ( sprintf("%i - used: %.2fmb, diff: %.2fmb", $i, get_mem(), get_mem() - $start_mem ) );
    }
    ++$i;
}
my $diff = get_mem() - $start_mem;
ok( $diff < 1, "memory usage hasn't risen by more than 1mb (${diff}mb)" );

sub get_mem {
    my $mem = `grep VmRSS /proc/$$/status`;
    return [split(qr/\s+/, $mem)]->[1] / 1024;
}
