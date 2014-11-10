use Test::More tests => 9;
use strict;
use warnings;

use Data::Dumper;
use Sys::Hostname;

# Let's not repeat this.
sub prompt {
    my ($message) = @_;

    print "$message: ";
    my $to_return = <STDIN>;
    chomp($to_return);

    return $to_return;
}

my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";
my $dtag
    = ( unpack( "L", pack( "N", 1 ) ) != 1 )
    ? '0100000000000000'
    : '0000000000000001';

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect( $host, { user => "guest", password => "guest" } ); };
is( $@, '', "connect" );
eval { $mq->channel_open(1); };
is( $@, '', "channel_open" );

my $exchange
    = prompt( "You are currently using the host >$host< for this test.\n"
        . "On your host, create an *fanout exchange* which publishes to a queue having a 1-second TTL\n"
        . "limit and publishes to a dead-letter exchange upon message expiration.\n"
        . "Make sure that your dead-letter exchange publishes to its own queue.\n"
        . "Also, make sure *all exchanges* have the same name as their queues!\n"
        . "What is the name of the exchange you created?" );
my $dlq_name
    = prompt("What is the name of the dead-letter queue you created?");

my $payload = "Message payload";
my $headers = {
    unsigned_integer => 12345,
    signed_integer   => -12345,
    double           => 3.141,
    string           => "string here",
};

eval {
    $mq->publish(
        1, q{}, $payload,
        { exchange => $exchange },
        { headers  => $headers }
    );
};
is( $@, '', "publish" );
die "Fatal publish failure!" if $@;

diag("Sleeping for two seconds...");
sleep(2);

my $getr = undef;
eval { $getr = $mq->get( 1, $dlq_name ); };
is( $@, '', "get" );
$getr->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
# diag( Dumper($getr) );

#Verify that the timestamp is within the last hour
# (allow the variance since the time may be different between the testing box and the server)...
my $now = time();
cmp_ok(
    $getr->{'props'}->{'headers'}->{'x-death'}->[0]->{'time'},
    '>=',
    ( $now - 3600 ),
    'x-death time minimum'
);
cmp_ok(
    $getr->{'props'}->{'headers'}->{'x-death'}->[0]->{'time'},
    '<=',
    ( $now + 3600 ),
    'x-death time maximum'
);

# Override the time in x-death so we can is_deeply()
$getr->{'props'}->{'headers'}->{'x-death'}->[0]->{'time'} = $now;

is_deeply(
    $getr,
    {   redelivered   => 0,
        routing_key   => q{},
        exchange      => $dlq_name,
        message_count => 1,
        delivery_tag  => $dtag,
        props         => {
            headers => {
                %{$headers},
                'x-death' => [
                    {   time           => $now,
                        exchange       => $exchange,
                        queue          => $exchange,
                        reason         => 'expired',
                        'routing-keys' => [q{}],
                    },
                ],
            },
        },
        body => $payload,
    },
    "get should see message"
);
