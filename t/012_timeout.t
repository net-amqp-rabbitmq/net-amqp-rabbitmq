use Test::More tests => 4;
use strict;
use Time::HiRes qw/gettimeofday tv_interval/;

my $host = '199.15.224.0'; # This OmniTI IP will hang
$SIG{'PIPE'} = 'IGNORE';
use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

my $start = [gettimeofday];
my $attempt = 3;
eval { $mq->connect($host, { user => "guest", password => "guest", timeout => $attempt }); };
my $duration = tv_interval($start);
isnt($@, '', "connect");
# 500ms tolerance should work with most operating systems
cmp_ok(abs($duration-$attempt), '<', 0.5, 'timeout');
