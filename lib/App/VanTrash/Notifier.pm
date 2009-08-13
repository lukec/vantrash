package App::VanTrash::Notifier;
use Moose;
use DateTime;
use App::VanTrash::Log;
use App::VanTrash::Twitter;
use namespace::clean -except => 'meta';

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

    my $as_of = $args{as_of} || DateTime->now;
    $as_of = $as_of->epoch;

    my @due;
    for my $rem (@{ $self->reminders->all('objects') }) {
        my $name = $rem->nice_name;
        unless ($rem->confirmed) {
            warn "reminder is not yet confirmed: $name\n" if $debug;
            next;
        }
        my $garbage_epoch = $rem->next_pickup;
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
    my $rem  = shift;

    my $pobj = $self->pickups->by_epoch($rem->zone, $rem->next_pickup);
    unless ($pobj) {
        warn "Cannot find '" . $rem->zone . "/" . $rem->next_pickup . "'\n";
        return;
    }
    
    $self->_send_notification($rem, $pobj);

    $rem->last_notified( $self->now() );
    $rem->update;
}


{
    my %target_map = (
        email => \&_send_notification_email,
        twitter => \&_send_notification_tweet,
    );

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
        my $func = $target_map{$type};
        unless ($func) {
            warn "No such target: $type for " . $rem->nice_name;
            return;
        }

        $self->log("Sending $type notification to $dest");
        $func->($self, 
            reminder => $rem,
            pickup   => $pickup,
            target   => $dest,
        );
    }
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
}

sub _send_notification_tweet {
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

    $self->twitter->new_direct_message($args{target}, $msg);
}

sub _build_twitter { App::VanTrash::Twitter->new }

# Tests can override this
sub now { time() }

__PACKAGE__->meta->make_immutable;
1;
