#!/usr/bin/perl
use strict;
use warnings;

use HTTP::Engine;

my $engine = HTTP::Engine->new(
    interface => {
        module => 'ServerSimple',
        args => {
            host => 'localhost',
            port =>  1978,
        },
        request_handler => 'main::handle_request',
    },
);
$engine->run;

sub handle_request {
    HTTP::Engine::Response->new( body => 'hello world' );
}
