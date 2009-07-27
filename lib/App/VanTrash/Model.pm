package App::VanTrash::Model;
use Moose;
use YAML qw/LoadFile DumpFile/;
use DateTime;
use Fatal qw/rename/;
use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;
use namespace::clean -except => 'meta';
use Carp qw/croak/;
use App::VanTrash::Email;

has 'base_path'     => (is => 'ro', isa => 'Str',      required   => 1);
has 'zonefile'      => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'reminderfile'  => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'zones'         => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
has 'zonehash'      => (is => 'ro', isa => 'HashRef',  lazy_build => 1);
has 'reminderhash'  => (is => 'rw', isa => 'HashRef',  lazy_build => 1);
has 'mailer'        => (is => 'ro', isa => 'Object',   lazy_build => 1);

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

    my $days = $self->days($zone);
    my $now = time;
    my @return;
    for my $d (@$days) {
        my $dt = DateTime->new(
            (map { $_ => $d->{$_} } qw/year month day/),
            time_zone => 'America/Vancouver',
        );
        next if $now > $dt->epoch;
        push @return, $d->{string};
        last if @return == $limit;
    }
    return @return;
}

sub all_reminders {
    my $self = shift;
    
    my $hash = $self->reminderhash;
    my @reminders;
    for my $zone (keys %{ $hash->{id} }) {
        push @reminders, values %{ $hash->{id}{$zone} };
    }
    return \@reminders;
}

sub get_reminder {
    my $self = shift;
    my $zone = shift or croak "A zone is mandatory!";
    my $id   = shift or croak "An id is mandatory!";
    return $self->reminderhash->{$zone}{id}{$id};
}

sub get_reminder_by_confirm_hash {
    my $self = shift;
    my $zone = shift;
    my $hash = shift;
    return $self->reminderhash->{$zone}{confirm}{$hash};
}

sub add_reminder {
    my $self = shift;
    my $rem  = shift or croak "A reminder is mandatory!";

    $self->reminderhash->{$rem->zone}{id}{$rem->id} = $rem;
    $self->reminderhash->{$rem->zone}{confirm}{$rem->confirm_hash} = $rem;
    $self->save_reminderhash;

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

    $rem->confirmed(1);
    delete $self->reminderhash->{$rem->zone}{confirm}{$rem->confirm_hash};
    $self->save_reminderhash;

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
    my $zone = shift or croak 'A zone is mandatory!';
    my $id   = shift or croak 'An id is mandatory!';

    my $rem = $self->get_reminder($zone, $id);
    return unless $rem;
    delete $self->reminderhash->{$zone}{id}{$id};
    delete $self->reminderhash->{$zone}{confirm}{$rem->confirm_hash};
    $self->save_reminderhash;
    return $rem;
}

sub save_reminderhash {
    my $self = shift;
    my $tmp = "/tmp/reminder.$$";
    DumpFile($tmp, $self->reminderhash);
    rename $tmp => $self->reminderfile;
}

sub _build_zones {
    my $self = shift;
    return [sort {$a cmp $b} keys %{ $self->zonehash }];
}

sub _build_zonehash      { shift->_load_file('zone') }

sub _build_reminderhash {
    my $self = shift;
    return $self->_load_file('reminder');
}

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

sub _build_reminderfile {
    my $self = shift;
    return $self->base_path . "/data/reminders.yaml";
}

sub _build_mailer {
    my $self = shift;
    return App::VanTrash::Email->new( base_path => $self->base_path );
}

__PACKAGE__->meta->make_immutable;
1;
