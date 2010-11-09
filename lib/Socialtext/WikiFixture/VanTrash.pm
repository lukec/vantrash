package Socialtext::WikiFixture::VanTrash;
use Moose;
use Test::More;
use Test::HTTP;
use JSON::XS qw(decode_json);
use Date::Parse qw(str2time);
use POSIX qw(strftime);
use DateTime;
use DateTime::Format::Strptime;
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

# Vantrash stuff

sub wait_for_kml {
    my $self = shift;
    $self->wait_for_condition('window.map.zones.length', 5000);
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

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
