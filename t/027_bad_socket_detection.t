use Test::More;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use NAR::Helper;

my $helper = NAR::Helper->new;
$helper->plan(18);

ok !$helper->channel_open,          "no socket, no channel_open";
ok !$helper->exchange_declare,      "no socket, no exchange_declare";
ok !$helper->exchange_delete,       "no socket, no exchange_delete";
ok !$helper->queue_declare,         "no socket, no queue_declare";
ok !$helper->queue_delete,          "no socket, no queue_delete";
ok !$helper->queue_bind,            "no socket, no queue_bind";
ok !$helper->queue_unbind,          "no socket, no queue_unbind";
ok !$helper->consume,               "no socket, no consume";
ok !$helper->recv,                  "no socket, no recv";
ok !$helper->ack("dummy"),          "no socket, no ack";
ok !$helper->nack("dummy"),         "no socket, no nack";
ok !$helper->reject("dummy"),       "no socket, no reject";
ok !$helper->cancel,                "no socket, no cancel";
ok !$helper->purge,                 "no socket, no purge";
ok !$helper->publish("dummy"),      "no socket, no publish";
ok !$helper->get,                   "no socket, no get";
ok !$helper->get_server_properties, "no socket, no get_server_properties";
ok !$helper->get_client_properties, "no socket, no get_client_properties";
