package App::VanTrash::Model;
use Moose;
use YAML qw/LoadFile DumpFile/;
use DateTime;
use Fatal qw/rename/;
use namespace::clean -except => 'meta';

has 'base_path'    => (is => 'ro', isa => 'Str',      required   => 1);
has 'zonefile'     => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'reminderfile' => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'zones'        => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
has 'zonehash'     => (is => 'ro', isa => 'HashRef',  lazy_build => 1);
has '_reminderhash' => (is => 'rw', isa => 'HashRef', lazy_build => 1);

sub days {
    my $self = shift;
    my $zone = shift;
    return [sort {$a cmp $b} @{ $self->zonehash->{$zone} }];
}

sub next_pickup {
    my $self = shift;
    my $zone = shift;

    my $days = $self->days($zone);
    my $now = time;
    for my $d (@$days) {
        $d =~ m/^(\d+)-(\d+)-(\d+)$/;
        my $dt = DateTime->new(year => $1, month => $2, day => $3,
                               time_zone => 'America/Vancouver');
        next if $now > $dt->epoch;
        return $d;
    }
    return "N/A";
}

sub reminders {
    my $self = shift;
    my $zone = shift;

    return [ keys %{ $self->reminderhash->{$zone} } ];
}

sub get_reminder {
    my $self = shift;
    my $zone = shift;
    my $id   = shift;
    return $self->reminderhash->{$zone}{$id};
}

sub add_reminder {
    my $self = shift;
    my $zone = shift;
    my $rem  = shift;

    $rem->{offset} ||= -6;
    $self->reminderhash->{$zone}{$rem->{id}} = $rem;
    $self->save_reminderhash;
}

sub delete_reminder {
    my $self = shift;
    my $zone = shift;
    my $id   = shift;

    return unless $self->get_reminder($zone, $id);
    delete $self->reminderhash->{$zone}{$id};
    $self->save_reminderhash;
}

sub save_reminderhash {
    my $self = shift;
    my $tmp = $self->reminderfile . ".tmp";
    DumpFile($tmp, $self->reminderhash);
    rename $tmp => $self->reminderfile;
}

sub _build_zones {
    my $self = shift;
    return [sort {$a cmp $b} keys %{ $self->zonehash }];
}

sub _build_zonehash      { shift->_load_file('zone') }
sub _build__reminderhash { shift->_load_file('reminder') }

sub reminderhash {
    my $self = shift;

    my $file = $self->reminderfile;
    my $last_modified = $self->{_modified}{$file};
    if ($last_modified and $last_modified < (stat($file))[9]) {
        $self->_reminderhash( $self->_load_file('reminder') );
    }
    return $self->_reminderhash;
}

sub _load_file {
    my $self = shift;
    my $name = $_[0] . 'file';
    my $file = $self->$name;
    return {} unless -e $file;
    $self->{_modified}{$file} = (stat($file))[9];
    return LoadFile($file);
}

sub _build_zonefile {
    my $self = shift;
    return $self->base_path . "/trash-zone-times.yaml";
}

sub _build_reminderfile {
    my $self = shift;
    return $self->base_path . "/trash-reminders.yaml";
}

__PACKAGE__->meta->make_immutable;
1;
