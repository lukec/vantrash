#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::VanTrash::Controller;

my $port = 1009 + $<;
warn "Starting up HTTP server on port $port\n";

$ENV{DEV_ENV} = 1;

App::VanTrash::Controller->new(
    http_module => 'ServerSimple',
    http_args => {
        port => $port,
        host => 'localhost',
        net_server => 'Net::Server::PreForkSimple',
        net_server_configure => {
            max_servers  => 1,
            max_requests => 100,
        },
    },
    base_path => "$FindBin::Bin/..",
)->run;
exit;
