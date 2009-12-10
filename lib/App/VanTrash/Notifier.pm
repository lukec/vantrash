package App::VanTrash::Notifier;
use Moose;
use DateTime;
use App::VanTrash::Log;
use App::VanTrash::Twitter;
use JSON qw/encode_json/;
use namespace::clean -except => 'meta';

has 'model'          => (is => 'ro', isa => 'Object', required   => 1);
has 'mailer'         => (is => 'ro', isa => 'Object', required   => 1);
has 'reminders'      => (is => 'ro', isa => 'Object', required   => 1);
has 'pickups'        => (is => 'ro', isa => 'Object', required   => 1);
has 'sender_factory' => (is => 'ro', isa => 'Object', lazy_build => 1);
has 'twitter'        => (is => 'ro', isa => 'Object', lazy_build => 1);
has 'logger' =>
    (default => sub { App::VanTrash::Log->new }, handles => ['log']);

sub need_notification {
    my $self = shift;
    my %args = @_;
    my $debug = $args{debug} || $ENV{VT_DEBUG};

    my $as_of = $args{as_of} || $self->model->now;
    $as_of = $as_of->epoch;

    my @due;
    for my $rem (@{ $self->reminders->all('objects') }) {
        my $name = $rem->nice_name;
        warn "Examining $name ...\n" if $debug;
        unless ($rem->confirmed) {
            warn "reminder is not yet confirmed: $name\n" if $debug;
            next;
        }
        
        my $garbage_epoch = $rem->next_pickup;
        if ($garbage_epoch + 24*3600 < $self->model->now->epoch) {
            my $next = $self->model->next_pickup($rem->zone, 1, 'dt');
            warn "The next_pickup is out of date - next pickup is " 
                . $next->ymd . "\n";
            $rem->next_pickup($garbage_epoch = $next->epoch);
            $rem->update unless $debug;
        }
        my $rem_time = $garbage_epoch + $rem->offset * 3600;
        if ($rem->last_notified > $rem_time) {
            warn "reminder notification already sent for $name\n" if $debug;
            next;
        }
        if ($as_of < $rem_time) {
            warn "It is too early to send for $name\n" if $debug;
            next;
        }

        push @due, $rem;
    }
    $self->log("Found " . @due . " reminders due.");

    return \@due;
}

sub notify {
    my $self = shift;
    my $rem  = shift or die "reminder is undef!";

    my $pobj = $self->pickups->by_epoch($rem->zone, $rem->next_pickup);
    unless ($pobj) {
        warn "Cannot find '" . $rem->zone . "/" . $rem->next_pickup . "'\n";
        return;
    }
    
    if ($self->_send_notification($rem, $pobj)) {
        $rem->last_notified( $self->now() );
        $rem->update;
    }
}


sub _send_notification {
    my $self   = shift;
    my $rem    = shift;
    my $pickup = shift;

    my $target = $rem->target;
    unless ($target =~ m/^(\w+):(.+)/) {
        warn "Could not understand target: '$target' for " . $self->nice_name;
        return;
    }
    my ($type, $dest) = ($1, $2);
    my $method = "_send_notification_$type";
    unless ($self->can($method)) {
        die "No such target: $type for " . $rem->nice_name;
        return;
    }

    $self->log("SENDING $type notification to $dest");
    return $self->$method(
        reminder => $rem,
        pickup   => $pickup,
        target   => $dest,
    );
}

sub _send_notification_email {
    my $self = shift;
    my %args = @_;

    $self->mailer->send_email(
        to            => $args{target},
        subject       => 'It is garbage day',
        template      => 'notification.html',
        template_args => {
            reminder    => $args{reminder},
            garbage_day => $args{pickup},
        },
    );
    return 1;
}

sub _send_notification_twitter {
    my $self = shift;
    my %args = @_;

    my $msg = "It is garbage day on " . $args{pickup}->day
            . " for " . $args{reminder}->zone;
    if ($args{pickup}->flags eq 'Y') {
        $msg .= " - yard trimmings will be picked up";
    }
    else {
        $msg .= " - no yard trimming pickup today";
    }

    $msg .= ". To unsubscribe click: " . $args{reminder}->short_delete_url;

    unless ($self->twitter->new_direct_message($args{target}, $msg)) {
        if (my $error = $self->twitter->get_error()) {
            if ($error->{error} =~ m/not following you/) {
                $self->mailer->send_email(
                    to            => $args{reminder}->email,
                    subject       => 'Twitter VanTrash reminder failed!',
                    template      => 'twitter-fail.html',
                    template_args => {
                        reminder    => $args{reminder},
                        garbage_day => $args{pickup},
                        target => $args{target},
                    },
                );
                $self->log("Send Twitter fail email for $args{target}");

                # Lets call this a success because we emailed the person, and 
                # we don't want to keep emailing them over and over.
                return 1;
            }
            warn "Error sending tweet: $error->{error}";
            return 0;
        }
    }
    return 1;
}

sub _send_notification_webhook {
    my $self = shift;
    my %args = @_;

    my $body = encode_json {
        reminder => $args{reminder}->to_hash,
        pickup => $args{pickup}->to_hash,
    };

    $self->http_post( $args{target}, $body );
    return 1;
}

sub http_post {
    my $self = shift;
    my $url  = shift;
    my $body = shift;

    my $ua = LWP::UserAgent->new;
    $ua->post( $url, payload => $body );
}

sub _build_twitter { App::VanTrash::Twitter->new }

# Tests can override this
sub now { time() }

__PACKAGE__->meta->make_immutable;
1;
