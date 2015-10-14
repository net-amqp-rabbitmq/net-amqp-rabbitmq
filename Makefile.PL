use strict;
use warnings;
require 5.008 ;

use lib qw(inc);
use ExtUtils::MakeMaker 5.16 ;
use Config;
use FindBin qw/$Bin/;
use Devel::CheckLib;

my $ofiles = '';
foreach ( <$Bin/*.c> ){

    continue if ( $_ =~ m/assertlib/ );

    $_ =~ s/.c$/.o/;
    $ofiles .= "$_ ";
}

# This will help make the library compile on OSX
# (and hopefully Solaris as well, but I don't have one of those)
my $has_htonll = check_lib(
    function => 'return htonll(0);',
    header   => 'arpa/inet.h',
);
print "THE DHAVE_HTONLL VALUE IS >$has_htonll<\n";
my $htonll_ccflag = ($has_htonll) ? '-DHAVE_HTONLL' : '';

WriteMakefile(
    NAME            => 'Net::AMQP::RabbitMQ',
    VERSION_FROM    => 'RabbitMQ.pm',
    LICENSE         => 'mozilla_1_1',
    ABSTRACT_FROM   => 'RabbitMQ.pm',
    AUTHOR          => 'Mark Ellis <nobody@cpan.org>, Michael Stemle, Jr. <mstemle@cpan.org>',
    OBJECT          => "RabbitMQ.o ${ofiles}",
    OPTIMIZE        => $ENV{'OPTIMIZE'},
    CCFLAGS         => "$Config{ccflags} -I${Bin}",
    DEFINE          => "-DAMQ_PLATFORM='\"Perl_$^O_$^V\"' ${htonll_ccflag}",
    LIBS            =>['-lrt'],
    PREREQ_PM       => {
        'Math::Int64'      => 0.34,
    },
    META_MERGE        => {
        "meta-spec" => { version => 2 },
        "x_contributors" => [
            'jesus - Theo Schlossnagle <jesus@omniti.com>',
            'markellis - Mark Ellis <markellis@cpan.org>',
            'mstemle - Michael Stemle, Jr. <themanchicken@gmail.com>',
            'drolsky - Dave Rolsky <autarch@urth.org>',
            'srezic - Slaven Rezić <slaven@rezic.de>',
            'armand - Armand Leclercq <marman.email@gmail.com>',
            'dburke - Daniel W Burke <dburke@addictmud.org>',
            'davsx - Dávid Kovács',
            'iron-s - Alexey Sheynuk',
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
