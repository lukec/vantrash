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
        my $rem_time = $rem->next_pickup + $rem->offset * 3600;
        next if $rem->last_notified > $rem_time;
        next if $as_of < $rem_time;

        push @due, $rem;
    }

    return \@due;
}

1;
