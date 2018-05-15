package Net::AMQP::RabbitMQ;
use strict;
use warnings;

our $VERSION = '2.30001';

use XSLoader;
XSLoader::load "Net::AMQP::RabbitMQ", $VERSION;
use Scalar::Util qw(blessed);

=encoding UTF-8

=head1 NAME

Net::AMQP::RabbitMQ - interact with RabbitMQ over AMQP using librabbitmq

=head1 SYNOPSIS

  use Net::AMQP::RabbitMQ;
  my $mq = Net::AMQP::RabbitMQ->new();
  $mq->connect("localhost", { user => "guest", password => "guest" });
  $mq->channel_open(1);
  $mq->queue_declare(1, "queuename");
  $mq->publish(1, "queuename", "Hi there!");
  my $gotten = $mq->get(1, "queuename");
  print $gotten->{body} . "\n";
  $mq->disconnect();

=head1 DESCRIPTION

C<Net::AMQP::RabbitMQ> provides a simple wrapper around the librabbitmq library
that allows connecting, declaring exchanges and queues, binding and unbinding
queues, publishing, consuming and receiving events.

Error handling in this module is primarily achieve by C<Perl_croak> (die). You
should be making good use of C<eval> around these methods to ensure that you
appropriately catch the errors.

=head1 METHODS

All methods, unless specifically stated, return nothing on success
and die on failure.

Failure to be connected is a fatal failure for most methods.

=head2 new()

Creates a new Net::AMQP::RabbitMQ object.

=head2 connect( $hostname, $options )

Connect to RabbitMQ server.

C<$hostname> is the host to which a connection will be attempted.

C<$options> is an optional hash respecting the following keys:

    {
        user            => $user,        #default 'guest'
        password        => $password,    #default 'guest'
        port            => $port,        #default 5672
        vhost           => $vhost,       #default '/'
        channel_max     => $cmax,        #default 0
        frame_max       => $fmax,        #default 131072
        heartbeat       => $hearbeat,    #default 0
        timeout         => $seconds      #default undef (no timeout)

        ssl             => 1 | 0         #default 0
        ssl_verify_host => 1 | 0         #default 1
        ssl_cacert      => $caert_path   #needed for ssl
        ssl_init        => 1 | 0         #default 1, initilise the openssl library
    }

You probably don't want to touch C<ssl_init>, unless you know what it does.

For now there is no option to disable ssl peer checking, meaning to use C<ssl>, C<ssl_cacert> is required.

B<SSL NOTE>

if the connection is cut when using ssl, openssl will throw a C<SIGPIPE>, you should catch this or perl
will exit with error code 141

    $SIG{PIPE} = 'IGNORE';

=head2 disconnect()

Disconnect from the RabbitMQ server.

=head2 get_server_properties()

Get a reference to hash (hashref) of server properties.  These may vary, you should use C<Data::Dumper> to inspect.  Properties will be provided for the RabbitMQ server to which you are connected.

=head2 get_client_properties()

Get a reference to hash (hashref) of client properties.  These may vary, you should use C<Data::Dumper> to inspect.

=head2 is_connected()

Returns true if a valid socket connection appears to exist, false otherwise.

=head2 channel_open($channel)

Open an AMQP channel on the connection.

C<$channel> is a positive integer describing the channel you which to open.

=head2 channel_close($channel)

Close the specified channel.

C<$channel> is a positive integer describing the channel you which to close.

=head2 get_channel_max()

Returns the maximum allowed channel number.

=head2 exchange_declare($channel, $exchange, $options, $arguments)

Declare an AMQP exchange on the RabbitMQ server unless it already exists.  Bad
things will happen if the exchange name already exists and different parameters
are provided.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$exchange> is the name of the exchange to be instantiated.

C<$options> is an optional hash respecting the following keys:

     {
       exchange_type => $type,  #default 'direct'
       passive => $boolean,     #default 0
       durable => $boolean,     #default 0
       auto_delete => $boolean, #default 0
     }

Note that the default for the C<auto_delete> option is different for C<exchange_declare> and for C<queue_declare>.

C<$arguments> is an optional hash of additional arguments to the RabbitMQ server, such as:

     {
       # exchange to try if no routes apply on this exchange
       alternate_exchange => 'alternate_exchange_name',
     }

=head2 exchange_delete($channel, $exchange, $options)

Delete a AMQP exchange on the RabbitMQ server.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$exchange> is the name of the exchange to be deleted.

C<$options> is an optional hash respecting the following keys:

     {
       if_unused => $boolean,   #default 1
     }

=head2 exchange_bind($channel, $destination, $source, $routing_key, $arguments)

Bind a source exchange to a destination exchange with a given routing key and/or parameters.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$destination> is a previously declared exchange, C<$source> is
yet another previously declared exchange, and C<$routing_key> is
the routing key that will bind the specified source exchange to
the specified destination exchange.

C<$arguments> is an optional hash which will be passed to the server.  When
binding to an exchange of type C<headers>, this can be used to only receive
messages with the supplied header values.

=head2 exchange_unbind($channel, $destination, $source, $routing_key, $arguments)

Remove a binding between source and destination exchanges.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$destination> is a previously declared exchange, C<$source> is
yet another previously declared exchange, and C<$routing_key> is
the routing key that will B<unbind> the specified source exchange from
the specified destination exchange.

C<$arguments> is an optional hash which will be passed to the server.  When
binding to an exchange of type C<headers>, this can be used to only receive
messages with the supplied header values.

=head2 queue_declare($channel, $queuename, $options, $arguments)

Declare an AMQP queue on the RabbitMQ server.

In scalar context, this method returns the queuename declared
(important for retrieving the auto-generated queuename in the
event that one was requested).

In array context, this method returns three items: queuename,
the number of message waiting on the queue, and the number
of consumers bound to the queue.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$queuename> is the name of the queuename to be instantiated.  If
C<$queuename> is undef or an empty string, then an auto generated
queuename will be used.

C<$options> is an optional hash respecting the following keys:

     {
       passive => $boolean,     #default 0
       durable => $boolean,     #default 0
       exclusive => $boolean,   #default 0
       auto_delete => $boolean, #default 1
     }

Note that the default for the C<auto_delete> option is different for C<exchange_declare> and for C<queue_declare>.

C<$arguments> is an optional hash which will be passed to the server
when the queue is created.  This can be used for creating mirrored
queues by using the x-ha-policy header.

=head2 queue_bind($channel, $queuename, $exchange, $routing_key, $arguments)

Bind the specified queue to the specified exchange with a routing key.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$queuename> is a previously declared queue, C<$exchange> is a
previously declared exchange, and C<$routing_key> is the routing
key that will bind the specified queue to the specified exchange.

C<$arguments> is an optional hash which will be passed to the server.  When
binding to an exchange of type C<headers>, this can be used to only receive
messages with the supplied header values.

=head2 queue_unbind($channel, $queuename, $exchange, $routing_key, $arguments)

Remove a binding between a queue and an exchange.  If this fails, you must reopen the channel.

This is like the C<queue_bind> with respect to arguments.  This command unbinds
the queue from the exchange.  The C<$routing_key> and C<$arguments> must match
the values supplied when the binding was created.

=head2 queue_delete($channel, $queuename, $options)

Delete a specified queue.  If this fails, you must reopen the channel.

C<$options> is an optional hash respecting the following keys:

     {
       if_unused    => $boolean,     #default 1
       if_empty     => $boolean,     #default 1
     }

=head2 publish($channel, $routing_key, $body, $options, $props)

Publish a message to an exchange.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$routing_key> is the name of the routing key for this message.

C<$body> is the payload to enqueue.

C<$options> is an optional hash respecting the following keys:

     {
       exchange => $exchange,                     #default 'amq.direct'
       mandatory => $boolean,                     #default 0
       immediate => $boolean,                     #default 0
       force_utf8_in_header_strings => $boolean,  #default 0
     }

The C<force_utf8_in_header_strings> option causes all headers which look like
strings to be treated as UTF-8. In an attempt to make this a non-breaking change,
this option is disabled by default. However, for all headers beginning with
C<x->, those are treated as UTF-8 regardless of this option (per spec).

C<$props> is an optional hash (the AMQP 'props') respecting the following keys:

     {
       content_type => $string,
       content_encoding => $string,
       correlation_id => $string,
       reply_to => $string,
       expiration => $string,
       message_id => $string,
       type => $string,
       user_id => $string,
       app_id => $string,
       delivery_mode => $integer,
       priority => $integer,
       timestamp => $integer,
       headers => $headers # This should be a hashref of keys and values.
     }

=head2 consume($channel, $queuename, $options)

Put the channel into consume mode.

The C<consumer_tag> is returned.  This command does B<not> return AMQP
messages, for that the C<recv> method should be used.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$queuename> is the name of the queue from which we'd like to consume.

C<$options> is an optional hash respecting the following keys:

     {
       consumer_tag => $tag,    #absent by default
       no_local => $boolean,    #default 0
       no_ack => $boolean,      #default 1
       exclusive => $boolean,   #default 0
     }

=head2 recv($timeout)

Receive AMQP messages.

This method returns a reference to a hash (hashref) containing the following information:

     {
       body => 'Magic Transient Payload', # the reconstructed body
       routing_key => 'nr_test_q',        # route the message took
       exchange => 'nr_test_x',           # exchange used
       delivery_tag => 1,                 # (used for acks)
       redelivered => $boolean            # if message is redelivered
       consumer_tag => 'c_tag',           # tag from consume()
       props => $props,                   # hashref sent in
     }

C<$props> is the hash sent by publish() respecting the following keys:

     {
       content_type => $string,
       content_encoding => $string,
       correlation_id => $string,
       reply_to => $string,
       expiration => $string,
       message_id => $string,
       type => $string,
       user_id => $string,
       app_id => $string,
       delivery_mode => $integer,
       priority => $integer,
       timestamp => $integer,
     }

C<$timeout> is a positive integer, specifying the number of milliseconds to
wait for a message. If you do not provide a timeout (or set it to 0), then
this call will block until it receives a message. If you set it to -1 it will
return immediately (waiting 0 ms).

If you provide a timeout, then the C<recv> method returns C<undef> if the
timeout expires before a message is received from the server.

=head2 cancel($channel, $consumer_tag)

Take the channel out of consume mode previously enabled with C<consume>.

This method returns true or false indicating whether we got the expected
"cancel-ok" response from the server.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$consumer_tag> is a tag previously passed to C<consume()> or one that was
generated automatically as a result of calling C<consume()> without an
explicit tag.

=head2 get($channel, $queuename, $options)

Get a message from the specified queue (via C<amqp_basic_get()>).

The method returns C<undef> immediately if no messages are available
on the queue.  If a message is available a reference to a hash (hashref) is
returned with the following contents:

    {
      body => 'Magic Transient Payload', # the reconstructed body
      routing_key => 'nr_test_q',        # route the message took
      exchange => 'nr_test_x',           # exchange used
      content_type => 'foo',             # (only if specified)
      delivery_tag => 1,                 # (used for acks)
      redelivered => 0,                  # if message is redelivered
      message_count => 0,                # message count

      # Not all of these will be present. Consult the RabbitMQ reference for more details.
      props => {
        content_type => 'text/plain',
        content_encoding => 'none',
        correlation_id => '123',
        reply_to => 'somequeue',
        expiration => 1000,
        message_id => 'ABC',
        type => 'notmytype',
        user_id => 'guest',
        app_id => 'idd',
        delivery_mode => 1,
        priority => 2,
        timestamp => 1271857990,
        headers => {
          unsigned_integer => 12345,
          signed_integer   => -12345,
          double           => 3.141,
          string           => "string here",

          # The x-death header is a special header for dead-lettered messages (rejected or timed out).
          'x-death' => [
            {
              time           => 1271857954,
              exchange       => $exchange,
              queue          => $exchange,
              reason         => 'expired',
              'routing-keys' => [q{}],
            },
          ],
        },
      },
    }

C<$channel> is a channel that has been opened with C<channel_open>.

C<$queuename> is the name of the queue from which we'd like to consume.

C<$options> is an optional hash respecting the following keys:

     {
       no_ack => $boolean,  #default 1
     }

=head2 ack($channel, $delivery_tag, $multiple = 0)

Acknowledge a message.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$delivery_tag> the delivery tag seen from a returned message from the
C<recv> method.

C<$multiple> specifies if multiple are to be acknowledged at once.

=head2 purge($channel, $queuename)

Purge all messages from the specified queue.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$queuename> is the queue to be purged.

=head2 reject($channel, $delivery_tag, $requeue = 0)

Reject a message with the specified delivery tag.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$delivery_tag> the delivery tag seen from a returned message from the
C<recv> method.

C<$requeue> specifies if the message should be requeued.

=head2 tx_select($channel)

Start a server-side (tx) transaction over $channel.

C<$channel> is a channel that has been opened with C<channel_open>.

=head2 tx_commit($channel)

Commit a server-side (tx) transaction over $channel.

C<$channel> is a channel that has been opened with C<channel_open>.

=head2 tx_rollback($channel)

Rollback a server-side (tx) transaction over $channel.

C<$channel> is a channel that has been opened with C<channel_open>.

=head2 basic_qos($channel, $options)

Set quality of service flags on the current $channel.

C<$channel> is a channel that has been opened with C<channel_open>.

C<$options> is an optional hash respecting the following keys:

     {
       prefetch_count => $cnt,  #default 0
       prefetch_size  => $size, #default 0
       global         => $bool, #default 0
     }

=head2 heartbeat()

Send a heartbeat.  If you've connected with a heartbeat parameter,
you must send a heartbeat periodically matching connection parameter or
the server may snip the connection.

=head2 has_ssl

Returns true if the module was compiled with SSL support, false otherwise

=head1 WARNING AND ERROR MESSAGES

=head2 Fatal Errors

It should be noted that almost all errors in this library are considered fatal,
insomuch as they trigger a C<croak()>. In these errors, if it appears that somehow
the connection has been closed by the remote host, or otherwise invalidated,
the socket will also be closed and should be re-opened before any additional
calls are made.

=head1 EXAMPLES

=head2 Simple publisher

    use Net::AMQP::RabbitMQ;

    my $channel = 1;
    my $exchange = "MyExchange.x";  # This exchange must exist already
    my $routing_key = "foobar";

    my $mq = Net::AMQP::RabbitMQ->new();
    $mq->connect("localhost", { user => "guest", password => "guest" });
    $mq->channel_open(1);
    $mq->publish($channel, $routing_key, "Message Here", { exchange => $exchange });
    $mq->disconnect();

=head2 Simple consumer

    use Net::AMQP::RabbitMQ;
    use Data::Dumper;

    my $channel = 1;
    my $exchange = "MyExchange.x";  # This exchange must exist already
    my $routing_key = "foobar";

    my $mq = Net::AMQP::RabbitMQ->new();
    $mq->connect("localhost", { user => "guest", password => "guest" });
    $mq->channel_open($channel);

    # Declare queue, letting the server auto-generate one and collect the name
    my $queuename = $mq->queue_declare($channel, "");

    # Bind the new queue to the exchange using the routing key
    $mq->queue_bind($channel, $queuename, $exchange, $routing_key);

    # Request that messages be sent and receive them until interrupted
    $mq->consume($channel, $queuename);

    while ( my $message = $mq->recv(0) )
      {
        print "Received message:\n";
        print Dumper($message);
      }

    $mq->disconnect();

=head1 RUNNING THE TEST SUITE

The test suite runs live tests against a RabbitMQ server at
C<rabbitmq.thisaintnews.com>.

There are separte variables for the ssl and none ssl host/user/password/port.

If you are in an environment that won't let you connect to this
host (or the test server is down), you can use these environment variables:

=over 4

=item MQHOST

Hostname or IP address of the RabbitMQ server to connect to (defaults
to C<rabbitmq.thisaintnews.com>).

=item MQUSERNAME

Username for authentication (defaults to "nartest").

=item MQPASSWORD

Password for authentication (defaults to "reallysecure").

=item MQPORT

Port of the RabbitMQ server to connect to (defaults to 5672)

=item MQSSL

Whether the tests should run with SSL enabled (defaults to false, but
see also C<MQSKIPSSL>).

=item MQSKIPSSL

Whether the SSL tests should be skipped entirely.  This option exists
because the SSL tests used to ignore C<MQSSL>, and to maintain
backwards compatibility, still do.

=item MQSSLHOST

Hostname or IP address of the RabbitMQ server to connect to (defaults
to C<rabbitmq.thisaintnews.com>).

=item MQSSLUSERNAME

Username for authentication (defaults to "nartest").

=item MQSSLPASSWORD

Password for authentication (defaults to "reallysecure").

=item MQSSLPORT

Port of the RabbitMQ server to connect to (defaults to 5673)

=item MQSSLCACERT

Path to the certificate file for SSL-enabled connections, defaults to
F<t/ssl/cacert.pem>.

=item MQSSLVERIFYHOST

Whether SSL hostname verification should be enabled (defaults to
true).

=item MQSSLINIT

Whether the openssl library should be initialized (defaults to true).

=back

=head1 VERSION COMPATIBILITY

This module was forked from L<Net::RabbitMQ> version 0.2.6 which uses an older
version of librabbitmq, and doesn't work correctly with newer versions of RabbitMQ.
The main change between this module and the original is this library uses
a newer, unforked, version of librabbitmq.

This means this module only works with the AMQP 0.9.1 protocol, so requires RabbitMQ
version 2+. Also, since the version of librabbitmq used is not a custom fork, it
means this module doesn't support the basic_return callback method.

=head1 AUTHORS

Theo Schlossnagle E<lt>jesus@omniti.comE<gt>

Mark Ellis E<lt>markellis@cpan.orgE<gt>

Michael Stemle, Jr. E<lt>themanchicken@gmail.comE<gt>

Dave Rolsky E<lt>autarch@urth.orgE<gt>

Slaven Rezić

Armand Leclercq

Daniel W Burke

Dávid Kovács

Alexey Sheynuk

Karen Etheridge E<lt>ether@cpan.orgE<gt>

Eric Brine E<lt>ikegami@cpan.orgE<gt>

=head1 LICENSE

This software is licensed under the Mozilla Public License. See the LICENSE file in the top distribution directory for the full license text.

librabbitmq is licensed under the MIT License. See the LICENSE-MIT file in the top distribution directory for the full license text.

=cut

sub publish {
    my ($self, $channel, $routing_key, $body, $options, $props) = @_;

    $options ||= {};
    $props   ||= {};

    # Do a shallow clone to avoid modifying variable passed by caller
    $props = { %$props };

    # Convert blessed variables in headers to strings
    if( $props->{headers} ) {
        $props->{headers} = { map { blessed($_) ? "$_" : $_ } %{ $props->{headers} } };
    }

    $self->_publish($channel, $routing_key, $body, $options, $props);
}

1;
