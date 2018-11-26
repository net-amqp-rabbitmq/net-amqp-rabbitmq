use strict;
use warnings;
require 5.008 ;
use utf8;

use lib qw(inc);
use ExtUtils::MakeMaker 5.16 ;
use Config;
use Devel::CheckLib;

# This will help make the library compile on OSX
# (and hopefully Solaris as well, but I don't have one of those)
my $has_htonll = check_lib(
    'function' => '
#ifdef htonll
return 0;
#else
return -1;
#endif
',
    'header'   => ['arpa/inet.h','stdio.h'],
    'lib' => 'c',
);

#XXX i wonder if we should check for socket and poll...
my @defines = ('-DHAVE_SOCKET', '-DHAVE_POLL', qq/-DAMQ_PLATFORM='"Perl_$^O_$^V"'/);
push @defines, '-DHAVE_HTONLL' if $has_htonll;

my @libs = ('-lrt');
my @inc = ('-I.', '-Irabbitmq-include');

my %checklib_extra_options;
if ( $^O eq 'darwin') {
    my $osx_homebrew_openssl_path = "/usr/local/opt/openssl";

    my $libpath = "${osx_homebrew_openssl_path}/lib";
    my $incpath = "${osx_homebrew_openssl_path}/include";

    push @libs, "-L$libpath";
    push @inc, "-I$incpath";

    $checklib_extra_options{libpath} = $libpath;
    $checklib_extra_options{incpath} = $incpath;
}

my $has_openssl = check_lib(
    lib     => [qw/ssl crypto/],
    header  => 'openssl/conf.h',
    %checklib_extra_options,
);
if ( $has_openssl ) {
    push @defines, '-DNAR_HAVE_OPENSSL';
    push @libs, '-lssl', '-lcrypto';
    if ( $^O eq 'MSWin32' ) {
        push @inc, "-Irabbitmq-include/win32";
    }
    else {
        push @inc, "-Irabbitmq-include/unix";
    }
}

my $ofiles = '';
foreach ( <*.c> ){
    next if ( $_ =~ m/assertlib/ );
    next if ( ( $_ eq 'amqp_openssl.c' ) && !$has_openssl );
    next if ( ( $_ eq 'threads.c' ) && ( $^O ne 'MSWin32' ) );

    #this shouldn't exist unless the build dir is unclean. so ignore it
    next if $_ eq 'RabbitMQ.c';

    $_ =~ s/.c$/.o/;
    $ofiles .= "$_ ";
}

my %WriteMakefileArgs = (
    NAME            => 'Net::AMQP::RabbitMQ',
    VERSION_FROM    => 'RabbitMQ.pm',
    LICENSE         => 'mozilla_1_1',
    ABSTRACT_FROM   => 'RabbitMQ.pm',
    AUTHOR          => 'Mark Ellis <markellis@cpan.org>, Michael Stemle, Jr. <mstemle@cpan.org>',
    OBJECT          => "RabbitMQ.o ${ofiles}",
    OPTIMIZE        => $ENV{'OPTIMIZE'},
    DEFINE          => join( ' ', @defines ),
    LIBS            => join( ' ', @libs ),
    INC             => join( ' ', @inc ),
    PREREQ_PM       => {
        'Math::Int64'      => '0.34',
        'Scalar::Util'     => '0',
        'XSLoader'         => '0',
    },
    TEST_REQUIRES   => {
        'Sys::Hostname'    => '0',
        'Test::More'       => '0',
        'Time::HiRes'      => '0',
    },
    META_MERGE        => {
        "meta-spec" => { version => 2 },
        "dynamic_config" => 1,
        "x_contributors" => [
            'jesus - Theo Schlossnagle <jesus@omniti.com>',
            'markellis - Mark Ellis <markellis@cpan.org>',
            'mstemle - Michael Stemle, Jr. <mstemle@cpan.org>',
            'drolsky - Dave Rolsky <autarch@urth.org>',
            'srezic - Slaven Rezić <slaven@rezic.de>',
            'armand - Armand Leclercq <marman.email@gmail.com>',
            'dburke - Daniel W Burke <dburke@addictmud.org>',
            'davsx - Dávid Kovács <davs@cpan.org>',
            'iron-s - Alexey Sheynuk',
            'ether - Karen Etheridge <ether@cpan.org>',
            'FGA - Fabrice Gabolde <fga@cpan.org>',
            'ikegami - Eric Brine <ikegami@cpan.org>',
        ],
        resources => {
            bugtracker  => {
                web    => 'https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/issues',
            },
            repository => {
                type => 'git',
                url => 'git://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq.git',
                web => 'https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq',
            },
        },
    },
);

if (!eval { ExtUtils::MakeMaker->VERSION('6.6303') }) {
    $WriteMakefileArgs{BUILD_REQUIRES} = $WriteMakefileArgs{TEST_REQUIRES};
    delete $WriteMakefileArgs{TEST_REQUIRES};
}

WriteMakefile(%WriteMakefileArgs);
