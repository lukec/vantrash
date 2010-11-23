package Socialtext::WikiFixture::VanTrash;
use Moose;
use Test::More;
use Test::HTTP;
use JSON::XS qw(decode_json);
use YAML;
use Date::Parse qw(str2time);
use POSIX qw(strftime);
use DateTime;
use DateTime::Format::Strptime;
use App::VanTrash::Config;
use App::VanTrash::Template;
use namespace::clean -except => 'meta';

extends 'Socialtext::WikiFixture::Selenese';

has 'http' => (
    is => 'ro', isa => 'Test::HTTP', lazy_build => 1
);

sub _build_http {
    my $self = shift;
    return Test::HTTP->new('vantrash');
};

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';
    $uri = "$self->{browser_url}$uri" if $uri =~ m#^/#;
    $self->http->get($uri, [Accept => $accept]);
}

sub _api_get_next_pickup_date {
    my ($self, $zone) = @_;
    $self->get("/zones/$zone/nextpickup.json");
    my $data = decode_json($self->http->response->content);
    (my $date = $data->{'next'}[0]) =~ s{ Y$}{};
    my ($y, $m, $d) = split '-', $date;
    my $dt = DateTime->new(year => $y, month => $m, day=> $d);
    return sprintf(
        "%s %s %d %d", $dt->day_abbr, $dt->month_abbr, $dt->day, $dt->year
    );
}

sub set_scheme {
    my ($self, $var, $scheme) = @_;
    $self->{$var} =~ s{http://}{$scheme};
    diag "Set $var to $self->{$var}";
}

has 'config' => (
    is => 'ro', isa => 'App::VanTrash::Config', lazy_build => 1,
);

sub _build_config {
    App::VanTrash::Config->new(config_file => './etc/vantrash.yaml');
}

sub wait_for_email_ok {
    my ($self, $email_address) = @_;
    require Mail::POP3Client;

    my $pop = new Mail::POP3Client(
        USER     => $self->config->Value('tester_username'),
        PASSWORD => $self->config->Value('tester_password'),
        HOST     => "pop.gmail.com",
        USESSL   => 1,
    );

    $self->{email_body} = undef;

    for (0 .. 10) {
        $pop->Connect() >= 0 || die $pop->Message();
        for my $i (1 .. $pop->Count()) {
            for ($pop->Head($i)) {
                if (/^To:\s+(.*)/i and $1 eq $email_address) {
                    die "Multiple emails found!" if $self->{email_body};
                    $self->{email_body} = scalar $pop->Body($i);
                }
            }
        }
        $pop->Close();
        last if $self->{email_body};
        diag "Waiting for email...";
        sleep 1;
    }

    $self->{email_body} =~ s{\r}{}g;

    ok $self->{email_body}, 'wait_for_email_ok';
}

sub text_like {
    my $self = shift;
    my $text = shift;
    my $regex = shift;
    like $text, $regex, 'text_like';
}

sub text_unlike {
    my $self = shift;
    my $text = shift;
    my $regex = shift;
    unlike $text, $regex, 'text_like';
}

sub exec_regex {
    my $self = shift;
    my $name = shift;
    my $content = shift;
    my $regex = $self->quote_as_regex(shift || '');
    if ($content =~ $regex and $1) {
        $self->{$name} = $1;
        diag "Set $name to '$1'";
    }
    else {
        die "Could not set exec '$regex' on '$content'";
    }
}

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
