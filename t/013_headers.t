use Test::More tests => 26;
use strict;
use warnings;

use Sys::Hostname;
my $unique = hostname . "-$^O-$^V-$$"; #hostname-os-perlversion-PID
my $exchange = "nr_test_x-$unique";
my $queuename = "nr_test_hole-$unique";
my $routekey = "nr_test_route-$unique";

package TestBlessings;
use overload
	'""' => sub { uc ${$_[0]} },
	;

sub new {
	my ($class, $self) = @_;

	bless \$self, $class;
}

package main;

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq, "Created object");

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");

eval { $mq->channel_open(1); };
is($@, '', "channel_open");

# Re-establish the exchange if it wasn't created in 001
# or in 002
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "direct", passive => 0, durable => 1, auto_delete => 0, internal => 0 }); };
is($@, '', "exchange_declare");

eval { $mq->queue_declare(1, $queuename, { passive => 0, durable => 1, exclusive => 0, auto_delete => 0 }); };
is($@, '', "queue_declare");

eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

eval { 1 while($mq->get(1, $queuename)); };
is($@, '', "drain queue");

my $headers = {
	abc => 123,
	def => 'xyx',
	head3 => 3,
	head4 => 4,
	head5 => 5,
	head6 => 6,
	head7 => 7,
	head8 => 8,
	head9 => 9,
	head10 => 10,
	head11 => 11,
	head12 => 12,
};
eval { $mq->publish( 1, $routekey, "Header Test",
		{ exchange => $exchange },
		{ headers => $headers },
	);
};

is( $@, '', "publish" );

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $msg;
eval { $msg = $mq->recv() };
is( $@, '', 'recv' );

is( $msg->{body}, 'Header Test', "Received body" );
is( exists $msg->{props}, 1, "Props exist" );
is( exists $msg->{props}{headers}, 1, "Headers exist" );
is_deeply( $msg->{props}{headers}, $headers, "Received headers" );

$headers = {
    blah   => TestBlessings->new('foo'),
    array  => [1..100],
    hash   => {
        foo       => 'bar',
        something => 1234,
        another   => [qw/bacon double cheese burger please/, {test => 123, testing => 'testing'}],
    }
};
eval { $mq->publish( 1, $routekey, "Header Test",
		{ exchange => $exchange },
		{ headers => $headers },
	);
};
is( $@, '', 'publish with blessed header values' );

eval { $msg = $mq->recv() };
is( $@, '', 'recv from blessed header values' );

is_deeply( $msg->{props}{headers}, $headers, "Received blessed headers" );



SKIP: {
  skip "overload not supported on this perl", 3
    unless eval <<'PERL';
package ItsAKindaMagic;
use overload '""' => sub { "one prize, one goal" };
sub new { return bless {}, shift }
package main;
1;
PERL

  my $headers = { blah => ItsAKindaMagic->new() };
	eval { $mq->publish( 1, $routekey, "Header Test",
			{ exchange => $exchange },
			{ headers => $headers },
		);
	};
	is( $@, '', 'publish with magic header values' );

	skip "Publish failed", 2 if $@;
	eval { $msg = $mq->recv() };
	is( $@, '', 'recv from magic header values' );

	is_deeply( $msg->{props}{headers}, $headers, "Received magic headers" );
};

# Clean up
eval { $mq->cancel(1, 'ctag'); };
is($@, '', 'cancel');

eval { 1 while($mq->purge(1, $queuename)); };
is($@, '', "purge queue");

eval { $mq->queue_unbind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_unbind");

eval { $mq->queue_delete(1, $queuename); };
is($@, '', "queue_delete");

eval { $mq->exchange_delete(1, $exchange); };
is($@, '', "exchange_delete");

1;