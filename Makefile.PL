use strict;
use warnings;
require 5.008 ;

use ExtUtils::MakeMaker 5.16 ;
use Config;
use FindBin qw/$Bin/;

my $ofiles = '';
foreach ( <$Bin/*.c> ){
    $_ =~ s/.c$/.o/;
    $ofiles .= "$_ ";
}

WriteMakefile(
    NAME            => 'Net::AMQP::RabbitMQ',
    VERSION_FROM    => 'RabbitMQ.pm',
    LICENSE         => 'mozilla_1_1',
    ABSTRACT_FROM   => 'RabbitMQ.pm',
    AUTHOR          => 'Mark Ellis <nobody@cpan.org>, Michael Stemle, Jr. <mstemle@cpan.org>',
    OBJECT          => "RabbitMQ.o ${ofiles}",
    OPTIMIZE        => $ENV{'OPTIMIZE'},
    CCFLAGS         => "$Config{ccflags} -I${Bin}",
    DEFINE          => "-DAMQ_PLATFORM='\"Perl_$^O_$^V\"'",
    LIBS            =>['-lrt'],
    PREREQ_PM       => {
        'Math::Int64'      => 0.34,
    },
    META_MERGE        => {
        "meta-spec" => { version => 2 },
        "x_contributors" => [
            'jesus - Theo Schlossnagle <jesus@omniti.com>',
            'n0body - Mark Ellis <markellis@cpan.org>',
            'manchicken - Michael Stemle, Jr. <themanchicken@gmail.com>',
            'autarch - Dave Rolsky <autarch@urth.org>',
            'eserte - Slaven Rezić',
        ],
        resources => {
            bugtracker  => {
                web    => 'https://github.com/markwellis/net-amqp-rabbitmq/issues',
            },
            repository => {
                type => 'git',
                url => 'git://github.com/markwellis/net-amqp-rabbitmq.git',
                web => 'https://github.com/markwellis/net-amqp-rabbitmq',
            },
        },
    },
);
