use strict;
use warnings;
require 5.008 ;

use ExtUtils::MakeMaker 5.16 ;
use Config ;
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
    AUTHOR          => [
        'Theo Schlossnagle <jesus@omniti.com>',
        'Mark Ellis <nobody@cpan.org>',
    ],
    OBJECT          => "RabbitMQ.o ${ofiles}",
    OPTIMIZE        => $ENV{'OPTIMIZE'},
    CCFLAGS         => "-I${Bin}",
    LIBS            =>['-lrt'],
    META_MERGE        => {
        "meta-spec" => { version => 2 },
        resources => {
            bugtracker  => {
                web    => 'https://github.com/n0body-/net-amqp-rabbitmq/issues',
            },
            repository => {
                type => 'git',
                url => 'git://github.com/n0body-/net-amqp-rabbitmq.git',
                web => 'https://github.com/n0body-/net-amqp-rabbitmq',
            },
        },
    },
);
