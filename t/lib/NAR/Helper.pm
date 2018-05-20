package NAR::Helper;
use strict;
use warnings;

use Net::AMQP::RabbitMQ;
use Test::More ();
use Carp qw/carp/;

sub new {
    my ( $class, %options ) = @_;

    my $mq = Net::AMQP::RabbitMQ->new;
    my $unique = _unique();

    my $ssl = $ENV{MQSSL} ? 1 : 0;
    my $ssl_cacert = exists $ENV{MQSSLCACERT} ? $ENV{MQSSLCACERT} : "t/ssl/cacert.pem",
    my $ssl_verify_host = 1;
    if ( defined($ENV{MQSSLVERIFYHOST}) ) {
        $ssl_verify_host = $ENV{MQSSLVERIFYHOST};
    }
    my $ssl_init = 1;
    if ( defined($ENV{MQSSLINIT}) ) {
        $ssl_init = $ENV{MQSSLINIT};
    }

    #XXX we don't use this one yet, waiting on a librabbitmq upgrade
    my $ssl_verify_peer = 1;
    if ( defined($ENV{MQSSLVERIFYPEER}) ) {
        $ssl_verify_peer = $ENV{MQSSLVERIFYPEER};
    }

    my $port;
    my $host = "localhost";
    my $username = "guest";
    my $password = "guest";

    if ( $ssl || $options{ssl} ) {
        Test::More::note( "ssl mode" );

        $host = $ENV{MQSSLHOST} if exists $ENV{MQSSLHOST};
        $username = $ENV{MQSSLUSERNAME} if exists $ENV{MQSSLUSERNAME};
        $password = $ENV{MQSSLPASSWORD} if exists $ENV{MQSSLPASSWORD};
        $port = $ENV{MQSSLPORT} || 5671;
    }
    else {
        $host = $ENV{MQHOST} if exists $ENV{MQHOST};
        $username = $ENV{MQUSERNAME} if exists $ENV{MQUSERNAME};
        $password = $ENV{MQPASSWORD} if exists $ENV{MQPASSWORD};
        $port = $ENV{MQSSLPORT} || 5672;
    }

    my $self = {
        unique          => $unique,
        exchange        => "nar_excahnge-$unique",
        queue           => "nar_queue-$unique",
        routekey        => "nar_key-$unique",
        username        => $username,
        password        => $password,
        consumer_tag    => 'ctag',
        channel         => 1,
        port            => $port,
        host            => $host,
        mq              => $mq,
        ssl             => $ssl,
        ssl_verify_host => $ssl_verify_host,
        ssl_verify_peer => $ssl_verify_peer,
        ssl_cacert      => $ssl_cacert,
        ssl_init        => $ssl_init,
        %options,
    };
    if ( $ENV{NARDEBUG} ) {
        use Data::Dumper;
        warn Dumper( $self );
    }

    bless $self, $class;

    $self;
}

sub mq {
    $_[0]->{mq};
}

sub _unique {
    my $random = int rand 999999999;
    my $script_name = $0;
    $script_name =~ s|/|_|g;
    return "$^O-$^V-$$-$random-$script_name"; #os-perlversion-PID-random-test_name
}

sub _ok {
    my ( $self, $cb ) = @_;

    eval {
        $cb->();
    };
    Test::More::note( $@ ) if $@;

    return if $@;
    return 1;
}

sub connect {
    my ( $self, $heartbeat, $timeout ) = @_;

    my $options = {
        user            => $self->{username},
        password        => $self->{password},
        port            => $self->{port},
        ssl             => $self->{ssl},
        ssl_verify_host => $self->{ssl_verify_host},
        ssl_verify_peer => $self->{ssl_verify_peer},
        ssl_cacert      => $self->{ssl_cacert},
        ssl_init        => $self->{ssl_init},
    };
    if ( defined $heartbeat ) {
        $options->{heartbeat} = $heartbeat;
    }
    if ( defined $timeout ) {
        $options->{timeout} = $timeout;
    }

    $self->_ok( sub {
        $self->mq->connect( $self->{host}, $options );
    } );
}

sub heartbeat {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->heartbeat;
    } );
}

sub is_connected {
    my $self = shift;

    my $connected;
    $self->_ok( sub {
        $connected = $self->mq->is_connected;
    } );

    $connected;
}

sub channel_open {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->channel_open( $self->{channel} );
    } );
}

sub channel_close {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->channel_close( $self->{channel} );
    } );
}

sub exchange_declare {
    my ( $self, $options, $extra_name, $args ) = @_;

    if ( !defined $extra_name ) {
        $extra_name = "";
    }

    if ( !defined $options ) {
        $options = {
            exchange_type => "direct",
            passive       => 0,
            durable       => 1,
            auto_delete   => 0,
            internal      => 0,
        };
    }

    my $exchange = $self->{exchange} . $extra_name;
    $self->_ok( sub {
        $self->mq->exchange_declare( $self->{channel}, $exchange, $options, $args ? $args : () );
    } );
}

sub exchange_delete {
    my ( $self, $extra_name ) = @_;

    if ( !defined $extra_name ) {
        $extra_name = "";
    }

    my $exchange = $self->{exchange} . $extra_name;
    $self->_ok( sub {
        $self->mq->exchange_delete( $self->{channel}, $exchange, { if_unused => 0 } );
    } );
}

sub exchange_bind {
    my ( $self, $destination, $source, $args ) = @_;

    carp "destination needed" if !defined $destination;
    carp "source needed" if !defined $source;

    $self->_ok( sub {
        $self->mq->exchange_bind( $self->{channel}, $destination, $source, $self->{routekey}, $args ? $args : () );
    } );
}
sub exchange_unbind {
    my ( $self, $destination, $source, $args ) = @_;

    carp "destination needed" if !defined $destination;
    carp "source needed" if !defined $source;

    $self->_ok( sub {
        $self->mq->exchange_unbind( $self->{channel}, $destination, $source, $self->{routekey}, $args ? $args : () );
    } );
}

sub queue_declare {
    my ( $self, $options, $extra_name, $dynamic_queuename, $args ) = @_;

    if ( !defined $extra_name ) {
        $extra_name = "";
    }

    if ( !defined $options ) {
        $options = {
            passive     => 0,
            durable     => 1,
            exclusive   => 0,
            auto_delete => 0,
        };
    }

    my $queue;
    if ( !defined $dynamic_queuename ) {
        $queue = $self->{queue} . $extra_name;
    }
    else {
        $queue = '';
    }

    if ( wantarray ) {
        my @result;
        $self->_ok( sub {
            @result = $self->mq->queue_declare( $self->{channel}, $queue, $options, $args ? $args : () );
        } );

        return @result;
    }

    my $returned_queuename;
    $self->_ok( sub {
        $returned_queuename = $self->mq->queue_declare( $self->{channel}, $queue, $options );
    } );

    return $returned_queuename;
}

sub queue_bind {
    my ( $self, $queue, $exchange, $routekey, $args ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }
    if ( !defined $exchange ) {
        $exchange = $self->{exchange};
    }
    if ( !defined $routekey ) {
        $routekey = $self->{routekey};
    }

    $self->_ok( sub {
        $self->mq->queue_bind( $self->{channel}, $queue, $exchange, $routekey, $args ? $args : () );
    } );
}

sub queue_unbind {
    my ( $self, $queue, $exchange, $routekey, $args ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }
    if ( !defined $exchange ) {
        $exchange = $self->{exchange};
    }
    if ( !defined $routekey ) {
        $routekey = $self->{routekey};
    }

    $self->_ok( sub {
        $self->mq->queue_unbind( $self->{channel}, $queue, $exchange, $routekey, $args ? $args : () );
    } );
}

sub queue_delete {
    my ( $self, $queue ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }

    $self->_ok( sub {
        $self->mq->queue_delete( $self->{channel}, $queue, {if_unused => 0, if_empty => 0} );
    } );
}

sub drain {
    my ( $self, $queue ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }

    #why don't we use purge, because this way we can test get as well
    $self->_ok( sub {
        while ( $self->mq->get( $self->{channel}, $queue ) ) { 1 }
    } );
}

sub purge {
    my ( $self, $queue ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }

    #why don't we use purge, because this way we can test get as well
    $self->_ok( sub {
        $self->mq->purge( $self->{channel}, $queue );
    } );
}

sub publish {
    my ( $self, $body, $props, $routekey, $options ) = @_;

    carp "need body" if !defined $body;
    if ( !defined $routekey ) {
        $routekey = $self->{routekey};
    }
    if ( !defined $options ) {
        $options = {
            exchange => $self->{exchange},
        };
    }

    $self->_ok( sub {
        $self->mq->publish( $self->{channel}, $routekey, $body, $options, $props ) ;
    } );
}

sub cancel {
    my ( $self, $tag ) = @_;

    if ( !defined $tag ) {
        $tag = $self->{consumer_tag};
    }
    $self->_ok( sub {
        $self->mq->cancel( $self->{channel}, $tag );
    } );
}

sub consume {
    my ( $self, $queue, $no_ack, $no_local, $exclusive, $consumer_tag ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }
    if ( !defined $consumer_tag ) {
        $consumer_tag = $self->{consumer_tag};
    }
    if ( !defined $no_ack ) {
        $no_ack = 1;
    }
    if ( !defined $no_local ) {
        $no_local = 0;
    }
    if ( !defined $exclusive ) {
        $exclusive = 0;
    }

    my $options = {
        consumer_tag => $consumer_tag,
        no_local     => $no_local,
        no_ack       => $no_ack,
        exclusive    => $exclusive,
    };

    my $tag_back;
    $self->_ok( sub {
        $tag_back = $self->mq->consume( $self->{channel}, $queue, $options );
    } );

    return $tag_back;
}

sub recv {
    my ( $self, $timeout ) = @_;

    my $rv;
    $self->_ok( sub {
        $rv = $self->mq->recv( defined $timeout ? $timeout : () );
    } );

    return $rv;
}

sub get {
    my ( $self, $queue, $no_ack ) = @_;

    if ( !defined $queue ) {
        $queue = $self->{queue};
    }
    if ( !defined $no_ack ) {
        $no_ack = 1;
    }
    my $options = {
        no_ack => $no_ack ? 1 : 0,
    };

    my $rv;
    $self->_ok( sub {
        $rv = $self->mq->get( $self->{channel}, $queue, $options );
    } );

    return $rv;
}

sub disconnect {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->disconnect;
    } );
}

sub ack {
    my ( $self, $ack_tag, $multiple ) = @_;

    carp "need ack_tag" if !defined $ack_tag;
    $multiple = 0 if !defined $multiple;

    $self->_ok( sub {
        $self->mq->ack( $self->{channel}, $ack_tag, $multiple );
    } );
}
sub nack {
    my ( $self, $tag ) = @_;

    carp "need tag" if !defined $tag;
    $self->_ok( sub {
        $self->mq->nack( $self->{channel}, $tag, 0, 0 );
    } );
}


sub tx_select {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->tx_select( $self->{channel} );
    } );
}

sub tx_rollback {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->tx_rollback( $self->{channel} );
    } );
}

sub tx_commit {
    my $self = shift;

    $self->_ok( sub {
        $self->mq->tx_commit( $self->{channel} );
    } );
}

sub basic_qos {
    my ( $self, $options ) = @_;

    $self->_ok( sub {
        $self->mq->basic_qos( $self->{channel}, $options ? $options : () );
    } );
}

sub reject {
    my ( $self, $tag ) = @_;

    carp "need tag" if !defined $tag;
    $self->_ok( sub {
        $self->mq->reject( $self->{channel}, $tag );
    } );
}

sub get_server_properties {
    my $self = shift;

    my $server_properties;
    $self->_ok( sub {
        $server_properties = $self->mq->get_server_properties;
    } );

    $server_properties;
}

sub get_client_properties {
    my $self = shift;

    my $client_properties;
    $self->_ok( sub {
        $client_properties = $self->mq->get_client_properties;
    } );

    $client_properties;
}

sub cleanup {
    my ( $self, $queue ) = @_;

    Test::More::note( "cleaning up" );

    return 1 if !$self->mq->is_connected();

    $self->purge( $queue );
    $self->cancel;
    $self->queue_unbind( $queue );
    $self->queue_delete( $queue );
    $self->exchange_delete;
    $self->channel_close;

    1;
}

1;
