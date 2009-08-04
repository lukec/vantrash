package App::VanTrash::Notifier;
use Moose;
use DateTime;
use namespace::clean -except => 'meta';

has 'mailer'    => (is => 'ro', isa => 'Object',        required => 1);
has 'reminders' => (is => 'ro', isa => 'Object',        required => 1);

sub need_notification {
    my $self = shift;
    my %args = @_;

    my $as_of = $args{as_of} || DateTime->now;
    $as_of = $as_of->epoch;

    my @due;
    for my $rem (@{ $self->reminders->all }) {
        next unless $rem->confirmed;
        my $garbage_epoch = $rem->next_pickup;
        my $rem_time = $garbage_epoch + $rem->offset * 3600;
        next if $rem->last_notified > $rem_time;
        next if $as_of < $rem_time;

        push @due, $rem;
    }

    return \@due;
}

sub notify {
    my $self = shift;
    my $rem  = shift;

    my $garbage_day = DateTime->from_epoch( epoch => $rem->next_pickup );
    $self->mailer->send_email(
        to => $rem->email,
        subject => 'It is garbage day',
        template => 'notification.html',
        template_args => {
            reminder => $rem,
            garbage_day => $garbage_day->ymd,
        },
    );
    $rem->last_notified( $self->now() );
}

# Tests can override this
sub now { time() }

1;
