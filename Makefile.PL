use strict;
use warnings;
require 5.012;
use utf8;

use ExtUtils::MakeMaker;
use Config;

use FindBin qw/$Bin/;
use lib "$Bin/inc";
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
  'header' => [ 'arpa/inet.h', 'stdio.h' ],
  'lib'    => 'c',
);

#XXX i wonder if we should check for socket and poll...
my @defines =
  ( '-DHAVE_SOCKET', '-DHAVE_POLL', qq/-DAMQ_PLATFORM='"Perl_$^O_$^V"'/ );
push @defines, '-DHAVE_HTONLL' if $has_htonll;

my $OPTIMIZED_BUILD = $ENV{'OPTIMIZE'};
if ( ( $ARGV[-1] || 'NOPE' ) eq 'DEBUG' ) {
  push @defines, '-DDEBUG -ggdb3';
  $OPTIMIZED_BUILD = " ";
}

my @libs = ();
my @inc  = ( '-I.', '-Irabbitmq-include', '-Irabbitmq-c/include' );

my %checklib_extra_options;
if ( $^O eq 'darwin' ) {
  eval {
    require ExtUtils::PkgConfig;
    push @libs, ExtUtils::PkgConfig->libs('openssl');
    push @inc,  ExtUtils::PkgConfig->cflags('openssl');

    $checklib_extra_options{LIBS} = ExtUtils::PkgConfig->libs_only_L('openssl');
    $checklib_extra_options{INC} =
      ExtUtils::PkgConfig->cflags_only_I('openssl');
  };
  if ($@) {
    print "Unable to figure out where SSL is using pkg-config: $@\n";
  }
}

my $has_openssl = check_lib(
  lib    => [qw/ssl crypto/],
  header => 'openssl/conf.h',
  %checklib_extra_options,
);
if ($has_openssl) {
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
foreach (<*.c>) {
  next if ( $_ =~ m/assertlib/ );
  next if ( ( $_ eq 'amqp_openssl.c' ) && !$has_openssl );
  next if ( ( $_ eq 'threads.c' )      && ( $^O ne 'MSWin32' ) );

  #this shouldn't exist unless the build dir is unclean. so ignore it
  next if $_ eq 'RabbitMQ.c';

  $_ =~ s/.c$/.o/;
  $ofiles .= "$_ ";
}

my %WriteMakefileArgs = (
  NAME          => 'Net::AMQP::RabbitMQ',
  VERSION_FROM  => 'RabbitMQ.pm',
  LICENSE       => 'mozilla_1_1',
  ABSTRACT_FROM => 'RabbitMQ.pm',
  AUTHOR        =>
    'Mike "manchicken" Stemle <hello@mikestemle.com>',
  OBJECT    => "RabbitMQ.o ${ofiles}",
  OPTIMIZE  => $OPTIMIZED_BUILD,
  DEFINE    => join( ' ', @defines ),
  LIBS      => join( ' ', @libs ),
  INC       => join( ' ', @inc ),
  PREREQ_PM => {
    'Math::Int64'  => '0.34',
    'Scalar::Util' => '0',
    'XSLoader'     => '0',
  },
  TEST_REQUIRES => {
    'Sys::Hostname' => '0',
    'Test::More'    => '0',
    'Time::HiRes'   => '0',
  },
  META_MERGE => {
    "meta-spec"      => { version => 2 },
    "dynamic_config" => 1,
    "x_contributors" => [
      'mstemle - Mike "manchicken" Stemle <hello@mikestemle.com>',
      'jesus - Theo Schlossnagle <jesus@omniti.com>',
      'markellis - Mark Ellis <markellis@cpan.org>',
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
      bugtracker => {
        web => 'https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/issues',
      },
      repository => {
        type => 'git',
        url  => 'git://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq.git',
        web  => 'https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq',
      },
    },
  },
);

WriteMakefile(%WriteMakefileArgs);
