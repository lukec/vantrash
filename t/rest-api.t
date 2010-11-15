#!/usr/bin/perl
use strict;
use warnings;
use Plack::Test;
use Test::More;
use HTTP::Request::Common qw/GET POST DELETE/;
use t::VanTrash;
use App::VanTrash::Controller;
use JSON qw/encode_json/;

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

    # Rainy day: paid target w/o payment_period
    $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
        Content => q|{"email":"test@vantrash.ca","name":"Test","target":"voice:7787851357"}|
    );
    is $res->code, 400;
    like $res->content, qr/require payment period/;
};


# Create free reminder types
for my $target (qw{email:test@vantrash.ca twitter:vantrash webhook:http://vantrash.ca/webhook-eg}) {
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
            Content => qq|{"email":"test\@vantrash.ca","name":"Test","target":"$target"}|
        );
        is $res->code, 201, "create reminder - $target";
        is $res->content, '{}';
        ok $res->header('Location') =~ m#^/zones/vancouver-north-blue/reminders/([\w-]+)$#;
        my $reminder_id = $1;
        $res = $cb->(GET "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 200;
        is $res->header('Content-Type'), 'application/json';
        like $res->content, qr/"payment_period":null/;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 204, 'delete success';
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 400, 'cannot delete twice';
    };
}


# Create Premium reminder types
for my $target (qw{voice:7787851357 sms:7787851357}) {
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/zones/vancouver-north-blue/reminders", 
            Content => encode_json(
                {
                    email => 'test@vantrash.ca',
                    name => 'Test',
                    target => $target,
                    payment_period => 'month',
                },
            ),
        );
        is $res->code, 201, "create reminder - $target";
        ok $res->header('Location') =~ m#^/zones/vancouver-north-blue/reminders/([\w-]+)$#;
        my $reminder_id = $1;
        ok $res->header('Content-Type') =~ m#json#;
        like $res->content, qr|{"payment_url":"https://www\.sandbox\.paypal.+fake-paypal-token"}|;
        $res = $cb->(GET "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 200;
        is $res->header('Content-Type'), 'application/json';
        unlike $res->content, qr/"payment_period":null/;

        # Pretend we just agreed on paypal and we are back.
        $res = $cb->(GET "/billing/proceed?token=fake-paypal-token");
        is $res->code, 200;
        like $res->content, qr/Thank you for subscribing/;

        # Now delete the reminder
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 204;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 400;
    };
}

# TODO - paypal rainy day
# TODO - paypal rainy day - no token / bad token
# TODO - paypal cancel scenario

done_testing();
