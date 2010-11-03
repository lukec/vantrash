package Socialtext::WikiFixture::VanTrash;
use Moose;
use Test::More;
use Test::HTTP;
use JSON::XS qw(decode_json);
use Date::Parse qw(str2time);
use POSIX qw(strftime);
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
    return strftime("%a %b %d %Y", localtime(str2time($date)));
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
    $self->is_text_present_ok("Next pickup: $next_date");

    # Check that the calendar opens to the current month
    # XXX it should open to next month if no more days are this month
    my $month = strftime("%B/%Y", localtime(time));
    is $self->get_text('css=.month'), $month, "Calendar opens to $month";

    # Today is bolded
    my $date = int strftime("%d", localtime(time));
    is $self->get_text('css=.calendar .today'), $date, "Today is $date";
     
    # Get the pickup days using REST 
    $self->get("/zones/$zone/pickupdays.json");
    my $pickup_days = decode_json($self->http->response->content);

    # Click back until we get to the first month
    my $current_month = strftime("%Y-%m", localtime(time));
    my $first_month = "$pickup_days->[0]{year}-$pickup_days->[0]{month}";
    while ($current_month gt $first_month) {
        $self->click('css=.calendar .back');
        my $test = $self->get_text('css=.month');
        (my $first = $self->get_text('css=.month')) =~ s{/}{ 1 };
        $current_month = strftime("%Y-%m", localtime(str2time($first)));
        die "Unable to parse date: $first" unless $current_month;
    }

    # Each pickup day has the appropriate text
    for my $pickup_day (@$pickup_days) {
        # Skip old months for now
        my $ym = "$pickup_day->{year}-$pickup_day->{month}";

        if ($ym gt $current_month) {
            $self->click('css=.calendar .forward');
            $current_month = $ym;
        }

        # Verify the correct dates are marked
        my $num = $pickup_day->{day} - 1;
        my $day_selector = "dom=window.\$('.calendar .day').get($num)";
        like $self->get_attribute("$day_selector\@class"), qr/marked/,
            "$num is marked for pickup";

        # Make sure yard trimmings is set
        if ($pickup_day->{flags}) {
            like $self->get_attribute("$day_selector\@style"), qr/yard/,
                "$num is marked for yard trimmings pickup";
        }
        else{
            unlike $self->get_attribute("$day_selector\@style"), qr/yard/,
                "$num is NOT marked for yard trimmings pickup";
        }
    }
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
