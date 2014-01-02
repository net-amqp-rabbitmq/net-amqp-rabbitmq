use strict;
use warnings;
use Net::AMQP::RabbitMQ;
use Test::More tests => 8;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

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
eval { $mq->queue_bind(1, $queuename, "nr_test_x", "nr_test_q"); };
is($@, '', "queue_bind");

my $start_mem = get_mem();
my $i = 0;
while ( $i < 100_000 ) {
    $mq->tx_select(1);
    $mq->publish(1, "nr_test_q", "Magic Transient Payload (Commit)", { exchange => "nr_test_x" });
    $mq->tx_commit(1);
    if ( ( $i % 10_000 ) == 0 ) {
        diag ( sprintf("%i - used: %.2fmb, diff: %.2fmb", $i, get_mem(), get_mem() - $start_mem ) );
    }
    ++$i;
}
my $diff = get_mem() - $start_mem;
ok( $diff < 1, "memory usage hasn't risen by more than 2mb (${diff}mb)" );

sub get_mem {
    my $mem = `grep VmRSS /proc/$$/status`;
    return [split(qr/\s+/, $mem)]->[1] / 1024;
}
