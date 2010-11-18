#!/usr/bin/perl
use strict;
use warnings;
use Plack::Test;
use Test::More;
use HTTP::Request::Common qw/GET POST DELETE/;
use t::VanTrash;
use App::VanTrash::Controller;
use JSON qw/encode_json decode_json/;

no warnings 'redefine';

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
        my $blob = decode_json $res->content;
        ok !$blob->{payment_period}, 'free reminders have no payment_period';
        ok !$blob->{expiry}, 'free reminders have no expiry';
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
        my $blob = decode_json $res->content;
        is $blob->{payment_period}, 'month', 'monthly payment period';

        my $in_two_weeks = DateTime->today + DateTime::Duration->new(weeks=>2);
        is $blob->{expiry}, $in_two_weeks->epoch, 'expires in 2 weeks';

        # Pretend we just agreed on paypal and we are back.
        $res = $cb->(GET "/billing/proceed?token=fake-paypal-token");
        is $res->code, 200;
        like $res->content, qr/Thank you for subscribing/;

        # Now the paypal IPN comes in
        my $fake_ipn = {
            'payer_id' => 'TESTBUYERID01',
            'verify_sign' => 'AjPx9bf6MqOkbgZYNGr9bzU-kL1MAMVI76h9wdBoD7U561dLlB3yi4br',
            'residence_country' => 'US',
            'address_state' => 'CA',
            'mc_handling' => '2.06',
            'receiver_email' => 'seller@paypalsandbox.com',
            'item_number1' => 'AK-1234',
            'address_status' => 'confirmed',
            'payment_type' => 'instant',
            'address_city' => 'San Jose',
            'address_street' => '123, any street',
            'payment_status' => 'Completed',
            'mc_shipping1' => '1.02',
            'cmd' => '_notify-validate',
            'test_ipn' => '1',
            'txn_type' => 'cart',
            'address_country' => 'United States',
            'charset' => 'windows-1252',
            'payment_date' => '22:23:24 Nov 17, 2010 PST',
            'mc_handling1' => '1.67',
            'invoice' => 'abc1234',
            'quantity1' => '1',
            'payer_status' => 'unverified',
            'mc_fee' => '0.44',
            'address_zip' => '95131',
            'custom' => $reminder_id,
            'txn_id' => '241118623',
            'last_name' => 'Smith',
            'receiver_id' => 'TESTSELLERID1',
            'address_country_code' => 'US',
            'mc_shipping' => '3.02',
            'payer_email' => 'buyer@paypalsandbox.com',
            'tax' => '2.02',
            'address_name' => 'John Smith',
            'notify_version' => '2.4',
            'mc_gross_1' => '9.34',
            'item_name1' => 'something',
            'mc_currency' => 'USD',
            'first_name' => 'John'
        };
        %Business::PayPal::IPN::TEST_DATA = ( %$fake_ipn, completed => 1);
        $res = $cb->(POST "/billing/ipn", [ %$fake_ipn ]);
        is $res->code, 200, $res->content;

        # Now check the expiry was bumped ahead
        $res = $cb->(GET "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 200;
        is $res->header('Content-Type'), 'application/json';
        $blob = decode_json $res->content;
        is $blob->{payment_period}, 'month', 'monthly payment period';
        my $next_expiry = DateTime->today 
                            + DateTime::Duration->new(months=>1, weeks => 1);
        is $blob->{expiry}, $next_expiry->epoch, 'expires in 1 month + 1 week';

        # Now delete the reminder
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 204;
        $res = $cb->(DELETE "/zones/vancouver-north-blue/reminders/$reminder_id");
        is $res->code, 400;
    };
}

done_testing();
