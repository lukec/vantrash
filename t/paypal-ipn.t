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

# Unknown paypal txn_type: unknown created ipn

my $app = t::VanTrash->app;
my $reminder_id;
my $target = 'sms:7787851357';
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
    warn $res->content unless $res->code eq 201;
    ok(($res->header('location')||'') =~ m#^/zones/vancouver-north-blue/reminders/([\w-]+)$#);
    ok $reminder_id = $1, "Found a reminder_id";
};


# Important note about these tests.
#
# They _JUST_ test you get a 200. They DON'T test that our paypal logic does
# the right thing. This is a weakness.


my @ipns = (
    {
        name => 'recurring payment expired',
        json => <<'EOT',
{"rp_invoice_id":"87F9BD28-71E8-35B2-AACD-0820A90AEBE9","verify_sign":"A2S1fniRGsoquzRDbs4f5rc383f8AhSmtm-q5O5DFHHpSW4t4Uqe31YE","payer_id":"X3NE8YJDVY9Y6","residence_country":"CA","outstanding_balance":"0.00","last_name":"Closs","product_type":"1","receiver_email":"payments@vantrash.ca","amount_per_cycle":"9.99","initial_payment_amount":"9.99","next_payment_date":"N/A","profile_status":"Cancelled","period_type":" Regular","shipping":"0.00","payer_email":"luke@5thplane.com","time_created":"22:41:58 Nov 21, 2010 PST","cmd":"_notify-validate","currency_code":"CAD","txn_type":"recurring_payment_expired","tax":"0.00","charset":"windows-1252","notify_version":"3.0","amount":"9.99","recurring_payment_id":"I-3K9TK0U36EBT","payer_status":"verified","payment_cycle":"Yearly","first_name":"Luke","product_name":"9.99 per year for VanTrash notifications (test)"}
EOT
    },
    {
        name => 'recurring_payment',
        json => <<'EOT',
{"payer_id":"X3NE8YJDVY9Y6","rp_invoice_id":"818190C0-F606-11DF-BC7E-A8A4D686EF94","verify_sign":"AiKZhEEPLJjSIccz.2M.tbyW5YFwATr-tBZrmZ2TfDqof0nXeYuIjmQm","residence_country":"CA","address_state":"British Columbia","outstanding_balance":"0.00","receiver_email":"payments@vantrash.ca","initial_payment_amount":"0.01","address_status":"confirmed","payment_type":"instant","address_street":"2856 Eton St","business":"payments@vantrash.ca","address_city":"Vancouver","profile_status":"Active","period_type":" Regular","payment_status":"Completed","shipping":"0.00","time_created":"23:03:14 Nov 21, 2010 PST","currency_code":"CAD","cmd":"_notify-validate","txn_type":"recurring_payment","charset":"windows-1252","address_country":"Canada","payment_fee":"","payment_date":"03:44:09 Nov 22, 2010 PST","recurring_payment_id":"I-YP43GWBV0CU6","mc_fee":"0.01","payer_status":"verified","address_zip":"V5K1K5","payment_gross":"","txn_id":"7LG94264MM8687842","receiver_id":"N8LS5BT7AZ63C","last_name":"Closs","product_type":"1","amount_per_cycle":"0.01","address_country_code":"CA","next_payment_date":"02:00:00 Nov 23, 2010 PST","payer_email":"luke@5thplane.com","transaction_subject":"","address_name":"Luke Closs","tax":"0.00","notify_version":"3.0","mc_gross":"0.01","amount":"0.01","payment_cycle":"Daily","protection_eligibility":"Eligible","product_name":"VanTrash test subscription","first_name":"Luke","mc_currency":"CAD"}
EOT
    },
    {
        name => 'recurring_payment',
        json => <<'EOT',
{"payer_id":"X3NE8YJDVY9Y6","rp_invoice_id":"4DC58516-F610-11DF-A2C9-AB2DB6997E49","verify_sign":"AynlJ2zsmflH.74VEfIBZZJsEArxA-3oBd2xMwjkyD-4uhEAzudqGp2j","residence_country":"CA","address_state":"British Columbia","outstanding_balance":"0.00","receiver_email":"payments@vantrash.ca","initial_payment_amount":"15.00","address_status":"confirmed","payment_type":"instant","address_street":"2856 Eton St","business":"payments@vantrash.ca","address_city":"Vancouver","profile_status":"Active","period_type":" Regular","payment_status":"Completed","shipping":"0.00","time_created":"00:14:27 Nov 22, 2010 PST","currency_code":"CAD","cmd":"_notify-validate","txn_type":"recurring_payment","charset":"windows-1252","address_country":"Canada","payment_fee":"","payment_date":"03:45:15 Nov 22, 2010 PST","recurring_payment_id":"I-XFDY78R3HT6G","mc_fee":"0.74","payer_status":"verified","address_zip":"V5K1K5","payment_gross":"","txn_id":"4VL13286WK440322K","receiver_id":"N8LS5BT7AZ63C","last_name":"Closs","product_type":"1","amount_per_cycle":"15.00","address_country_code":"CA","next_payment_date":"02:00:00 Nov 22, 2011 PST","payer_email":"luke@5thplane.com","transaction_subject":"","address_name":"Luke Closs","tax":"0.00","notify_version":"3.0","mc_gross":"15.00","amount":"15.00","payment_cycle":"Yearly","protection_eligibility":"Eligible","product_name":"$15.00 per year for VanTrash notifications","first_name":"Luke","mc_currency":"CAD"}
EOT
    },
    {
        name => 'create',
        json => <<'EOT',
{
    "amount":"1.50",
    "amount_per_cycle":"1.50",
    "charset":"windows-1252",
    "currency_code":"CAD",
    "first_name":"Alicia",
    "initial_payment_amount":"0.00",
    "last_name":"Coppin",
    "next_payment_date":"02:00:00 Nov 26, 2010 PST",
    "notify_version":"3.0",
    "outstanding_balance":"0.00",
    "payer_email":"rhiannon.coppin@gmail.com",
    "payer_id":"2RPMLGHHZT4L6",
    "payer_status":"verified",
    "payment_cycle":"Monthly",
    "period_type":" Regular",
    "product_name":"$1.50 per month for VanTrash notifications",
    "product_type":"1",
    "profile_status":"Active",
    "receiver_email":"payments@vantrash.ca",
    "recurring_payment_id":"I-EHU2300WCPLJ",
    "residence_country":"CA",
    "rp_invoice_id":"A5AE2CFC-F9A7-11DF-94EE-00CDFBD97CDC",
    "shipping":"0.00",
    "tax":"0.00",
    "time_created":"13:58:51 Nov 26, 2010 PST",
    "txn_type":"recurring_payment_profile_created",
    "verify_sign":"A2S1fniRGsoquzRDbs4f5rc383f8Am-zqJdqFhzxP142COb2QHGdgEyp"
}
EOT
    },
);


for my $test (@ipns) {
    test_psgi $app, sub {
        my $cb = shift;

        (my $json = $test->{json}) =~ s/(rp_invoice_id":")[^"]+/$1$reminder_id/;
        my $blob = decode_json($json);
        %Business::PayPal::IPN::TEST_DATA = ( %$blob );
        my $res = $cb->(POST "/billing/ipn", [ %$blob ]);
        is $res->code, 200, $res->content;
    };
}
done_testing();
