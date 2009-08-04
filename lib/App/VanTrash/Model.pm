package App::VanTrash::Model;
use Moose;
use App::VanTrash::Email;
use App::VanTrash::DB;
use App::VanTrash::ReminderManager;
use App::VanTrash::Notifier;
use Carp qw/croak/;
use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;
use DateTime;
use Fatal qw/rename/;
use YAML qw/LoadFile DumpFile/;
use namespace::clean -except => 'meta';

has 'base_path'     => (is => 'ro', isa => 'Str',      required   => 1);
has 'zonefile'      => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'zones'         => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
has 'zonehash'      => (is => 'ro', isa => 'HashRef',  lazy_build => 1);
has 'mailer'        => (is => 'ro', isa => 'Object',   lazy_build => 1);
has 'reminders'     => (is => 'ro', isa => 'Object',   lazy_build => 1);
has 'db'            => (is => 'ro', isa => 'Object',   lazy_build => 1);
has 'notifier'      => (is => 'ro', isa => 'Object',   lazy_build => 1);

sub days {
    my $self = shift;
    my $zone = shift;
    my $days = [sort {$a cmp $b} @{ $self->zonehash->{$zone} || [] }];
    for my $d (@$days) {
        my ($day_string, $flag) = split ' ', $d;
        my ($year, $month, $day) = split '-', $day_string;
        $d = {
            year => $year,
            month => $month,
            day => $day,
            string => $d,
            flag => $flag || '',
        };
    }
    return $days;
}

sub ical {
    my $self = shift;
    my $zone = shift;
    my $days = $self->days($zone);

    my $ical = Data::ICal->new();
    for my $day (@$days) {
        my $evt = Data::ICal::Entry::Event->new;
        my $summary = 'Garbage pickup day';
        $summary .= ' & Yard trimmings day' if $day->{flag} eq 'Y';
        $evt->add_properties(
            summary => $summary,
            dtstart => Date::ICal->new(
                map { $_ => $day->{$_} } qw/year month day/,
                offset => "-0800",
            )->ical,
        );
        $ical->add_entry($evt);
    }

    return $ical->as_string;
}

sub next_pickup {
    my $self = shift;
    my $zone = shift;
    my $limit = shift || 1;
    my $datetime = shift;

    my $days = $self->days($zone);
    die "Not a valid zone: '$zone'\n" unless @$days;
    my $now = $self->now;
    $now->set( hour => 23, minute => 59 );
    my @return;
    for my $d (@$days) {
        my $dt = DateTime->new(
            (map { $_ => $d->{$_} } qw/year month day/),
            time_zone => 'America/Vancouver',
        );
        next if $now > $dt;
        push @return, ($datetime ? $dt : $d->{string});
        last if @return == $limit;
    }
    return wantarray ? @return : @return == 1 ? $return[0] : \@return;
}

sub add_reminder {
    my $self = shift;
    my $rem  = shift or croak "A reminder is mandatory!";

    my $next_pickup_dt = $self->next_pickup($rem->zone, 1, 'dt');
    $rem->next_pickup( $next_pickup_dt->epoch );
    $self->reminders->insert($rem);
    $self->mailer->send_email(
        to => $rem->email,
        subject => 'VanTrash Reminder Confirmation',
        template => 'reminder-confirm.html',
        template_args => {
            zone => $rem->zone,
            confirm_url => $rem->confirm_url,
        },
    );
    return $rem;
}

sub confirm_reminder {
    my $self = shift;
    my $rem = shift or croak 'A reminder is mandatory!';

    $self->reminders->confirm($rem);
    $self->mailer->send_email(
        to => $rem->email,
        subject => 'Your VanTrash reminder is created',
        template => 'reminder-success.html',
        template_args => {
            reminder => $rem,
        },
    );
}

sub delete_reminder {
    my $self = shift;
    my $id   = shift or croak 'An id is mandatory!';

    if (my $rem = $self->reminders->by_id($id)) {
        $self->reminders->delete($rem);
        return $rem;
    }
    return;
}

sub _build_zones {
    my $self = shift;
    return [sort {$a cmp $b} keys %{ $self->zonehash }];
}

sub _build_zonehash      { shift->_load_file('zone') }
sub _load_file {
    my $self = shift;
    my $name = $_[0] . 'file';
    my $file = $self->$name;
    return {} unless -e $file;
    my @stats = stat($file);
    $self->{_modified}{$file} = $stats[9];
    $self->{_size}{$file} = $stats[7];
    return LoadFile($file) || {};
}

sub _build_zonefile {
    my $self = shift;
    return $self->base_path . "/data/trash-zone-times.yaml";
}

sub _build_mailer {
    my $self = shift;
    return App::VanTrash::Email->new( base_path => $self->base_path );
}

sub _build_reminders {
    my $self = shift;
    return App::VanTrash::ReminderManager->load_or_create( 
        db => $self->db,
    );
}

sub _build_db {
    my $self = shift;
    return App::VanTrash::DB->new( base_path => $self->base_path );
}

sub _build_notifier {
    my $self = shift;
    return App::VanTrash::Notifier->new(
        reminders => $self->reminders,
        mailer    => $self->mailer,
    );
}

sub now {
    my $self = shift;
    my $dt = DateTime->now;
    $dt->set_time_zone('America/Vancouver');
    return $dt;
}

__PACKAGE__->meta->make_immutable;
1;
