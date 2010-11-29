package Socialtext::WikiFixture::VanTrash;
use Moose;
use Test::More;
use JSON::XS qw(decode_json);
use YAML;
use Date::Parse qw(str2time);
use POSIX qw(strftime);
use DateTime;
use DateTime::Format::Strptime;
use App::VanTrash::Config;
use App::VanTrash::Template;
use namespace::clean -except => 'meta';

extends qw(
    Socialtext::WikiFixture::Selenese
    Socialtext::WikiFixture::VanTrashRest
);

# Vantrash stuff

sub wait_for_kml {
    my $self = shift;
    $self->wait_for_condition('window.map && window.map.zones.length', 5000);
}

has 'zones' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1,
);
sub _build_zones {
    my $self = shift;
    my $js = '
        window.$.map(
            window.map.zones,function(z){return z.name}
        ).join(" ")
    ';
    return [ split ' ', $self->get_eval($js) ];
}

sub click_zone_ok {
    my $self = shift;
    my $zone = shift;

    my $i = 0;
    my %zones = map { $_ => $i++ } @{$self->zones};

    $self->get_eval_ok(
        "window.GEvent.trigger(window.map.zones[$zones{$zone}], 'click')",
        "Click zone '$zone'",
    );
};

sub calendar_ok {
    my $self = shift;
    my $zone = shift;

    # Next pickup date is correct
    my $next_date = $self->_api_get_next_pickup_date($zone);
    $self->wait_for_text_present_ok("Next pickup: $next_date");

    # Check that the calendar opens to the current month
    # XXX it should open to next month if no more days are this month
    my $current = DateTime->new(
        year => DateTime->now->year,
        month => DateTime->now->month,
        day => 1,
    );
    is $self->get_text('css=.ui-datepicker-month'), $current->month_name,
        "Calendar opens to current month";
    is $self->get_text('css=.ui-datepicker-year'), $current->year,
        "Calendar opens to current year";

    # Today is bolded
    my $date = int strftime("%d", localtime(time));
    is $self->get_text('css=.calendar .ui-datepicker-today'), $date,
        "Today is $date";
     
    # Get the pickup days using REST 
    $self->get("/zones/$zone/pickupdays.json");
    my $pickup_days = decode_json($self->http->response->content);

    # Click back until we get to the first month
    my $first = DateTime->new(
        year => $pickup_days->[0]{year},
        month => $pickup_days->[0]{month},
        day => 1,
    );

    # Step $current back until we get to first, clicking prev each time
    while (DateTime->compare($first, $current) < 0) {
        $self->click('css=.calendar .ui-datepicker-prev');
        $current->subtract(months => 1);
        die "Unable to parse date: $first" unless $current;
    }

    # First month is labelled correctly
    is $self->get_text('css=.ui-datepicker-month'), $current->month_name,
        "Month is " . $current->month_name;
    is $self->get_text('css=.ui-datepicker-year'), $current->year,
        "Year is " . $current->year;

    # Each pickup day has the appropriate text
    for my $pickup_day (@$pickup_days) {
        my $pickup_month = DateTime->new(
            year => $pickup_day->{year},
            month => $pickup_day->{month},
            day => 1,
        );

        # Click next if the pickup day is on the next month
        if (DateTime->compare($pickup_month, $current) > 0) {
            $self->click('css=.calendar .ui-datepicker-next');
            $current->add(months => 1);

            # Month is labelled correctly
            is $self->get_text('css=.ui-datepicker-month'),
                $current->month_name, "Month is " . $current->month_name;
            is $self->get_text('css=.ui-datepicker-year'), $current->year,
                "Year is " . $current->year;
        }

        # Verify the correct dates are marked
        my $num = $pickup_day->{day} - 1;
        my $day_selector = "dom=window.\$('.calendar .day').get($num)";
        like $self->get_attribute("$day_selector\@class"), qr/marked/,
            "$num is marked for pickup";

        # Make sure yard trimmings is set
        if ($pickup_day->{flags}) {
            like $self->get_attribute("$day_selector\@class"), qr/yard/,
                "$num is marked for yard trimmings pickup";
        }
        else{
            unlike $self->get_attribute("$day_selector\@class"), qr/yard/,
                "$num is NOT marked for yard trimmings pickup";
        }
    }
}

sub open_reminder_lightbox_ok {
    my ($self, $zone) = @_;
    $self->comment("Open reminder lightbox for $zone");
    $self->open_ok('/');
    $self->wait_for_page_to_load_ok(5000);
    $self->wait_for_kml;
    $self->click_zone_ok($zone);
    $self->wait_for_element_present_ok('css=.remind_me');
    $self->click_ok('css=.remind_me');
    $self->wait_for_text_present_ok('Schedule a weekly reminder:');
}

sub validate_and_enter_email_ok {
    my ($self, $el, $email) = @_;
    my @invalid = ('', 'nodomain', 'no@tld');

    ok !$self->is_text_present('Please enter a valid email');

    for (@invalid) {
        $self->type_ok($el, $_);
        $self->click_ok('css=.ui-dialog-buttonset .submit');
        $self->wait_for_text_present_ok('Please enter a valid email');
    }

    $self->type_ok($el, $email) if $email;
}

sub validate_and_enter_phone_ok {
    my ($self, $el, $phone) = @_;
    my @invalid = ('');

    ok !$self->is_text_present('Please enter your telephone number');

    $self->type_ok($el, '');
    $self->click_ok('css=.ui-dialog-buttonset .submit');
    $self->wait_for_text_present_ok('Please enter your telephone number');

    $self->type_ok($el, $phone) if $phone;
}

sub reminder_confirm_email_ok {
    my ($self, $email) = @_;

    $self->comment("Verifying confirmation email");

    $self->wait_for_email_ok($email);

    ($self->{confirm_url}) = $self->{email_body}
        =~ m!($self->{browser_url}/zones/[^/]+/reminders/[^/]+/confirm)!;
    ($self->{delete_url}) = $self->{email_body}
        =~ m!($self->{browser_url}/zones/[^/]+/reminders/[^/]+/delete)!;

    ok $self->{delete_url}, 'confirmation email has delete url';
    ok $self->{confirm_url}, 'confirmation email has confirm url';

    like $self->{email_body},
        qr{Thank you for signing up to the Vancouver Garbage Reminder service},
        'Thank you message';
}

sub reminder_success_email_ok {
    my ($self, $email, $target) = @_;

    $self->comment("Verifying success email");

    $self->wait_for_email_ok($email);

    ($self->{delete_url}) = $self->{email_body}
        =~ m!($self->{browser_url}/zones/[^/]+/reminders/[^/]+/delete)!;

    ok $self->{delete_url}, 'success email has delete url';

    if ($target eq 'twitter') {
        like $self->{email_body}, qr{You will now receive twitter reminders},
            'you will now receive twitter reminders';
        like $self->{email_body}, qr{http://twitter\.com/vantrash},
            "twitter success email links to vantrash's twitter";
    }
    elsif ($target eq 'email') {
        like $self->{email_body}, qr{You will now receive email reminders},
            'you will now receive email reminders';
    }
    elsif ($target eq 'sms') {
        like $self->{email_body},
            qr{You will now receive Text message reminders},
            'you will now receive email reminders';
    }
    elsif ($target eq 'phone') {
        like $self->{email_body}, qr{You will now receive Phone call reminders},
            'you will now receive email reminders';
    }

    unlike $self->{email_body}, qr{donate\.html}, "don't link to donate.html";
}

sub login_paypal_dev_ok {
    my $self = shift;
    $self->open_ok('http://developer.paypal.com');
    $self->wait_for_text_present_ok('Member Log In');
    $self->type_ok('login_email', $self->config->Value('paypal_dev_user'));
    $self->type_ok('login_password', $self->config->Value('paypal_dev_pwd'));
    $self->click_ok('css=form[name=login_form] *[type=submit]');
    $self->wait_for_text_present_ok('Log Out');
}

sub login_paypal_ok {
    my $self = shift;
    $self->is_text_present_ok('Create a PayPal Account or Log In');
    $self->type_ok('login_email', $self->config->Value('paypal_cust_user'));
    $self->type_ok('login_password', $self->config->Value('paypal_cust_pwd'));
    $self->click_ok('login.x');
    $self->wait_for_text_present_ok('Review your information');
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
