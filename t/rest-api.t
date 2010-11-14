#!/usr/bin/perl
use strict;
use warnings;
use Plack::Test;
use Test::More;
use HTTP::Request::Common qw/GET POST DELETE/;
use t::VanTrash;
use App::VanTrash::Controller;

my $app = t::VanTrash->app;
test_psgi $app, sub {
    my $cb = shift;

    # Sanity; check we have data in the DB
    my $res = $cb->(GET "/zones.txt");
    is $res->code, 200;
    like $res->content, qr/vancouver-north/;
    like $res->content, qr/vancouver-south/;

    # Rainy day: no email
    $res = $cb->(POST "/zones/vancouver-north-blue/reminders", Content => q|{}| );
    is $res->code, 400;
    like $res->content, qr/Bad email/;

    # Rainy day: no name
    $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
        Content => q|{"email":"test@vantrash.ca"}|
    );
    is $res->code, 400;
    like $res->content, qr/name is required/;

    # Rainy day: no target
    $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
        Content => q|{"email":"test@vantrash.ca","name":"Test"}|
    );
    is $res->code, 400;
    like $res->content, qr/target is required/;

    # Rainy day: bad target
    $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
        Content => q|{"email":"test@vantrash.ca","name":"Test","target":"invalid"}|
    );
    is $res->code, 400;
    like $res->content, qr/target is unsupported/;
};


# Create free reminder types
for my $target (qw{email:test@vantrash.ca twitter:vantrash webhook:http://vantrash.ca/webhook-eg}) {
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
            Content => qq|{"email":"test\@vantrash.ca","name":"Test","target":"$target"}|
        );
        is $res->code, 201;
        is $res->content, '';
        ok $res->header('Location') =~ m#^/zones/vancouver-north-blue/reminders/([\w-]+)$#;
        my $reminder_id = $1;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 204;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 400;
    };
}


# Create Premium reminder types
for my $target (qw{voice:7787851357 sms:7787851357}) {
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
            Content => qq|{"email":"test\@vantrash.ca","name":"Test","target":"$target"}|
        );
        is $res->code, 201;
        is $res->content, '';
        ok $res->header('Location') =~ m#^/zones/vancouver-north-blue/reminders/([\w-]+)$#;
        my $reminder_id = $1;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 204;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 400;
    };
}

done_testing();
