package App::VanTrash::Model;
use Moose;
use YAML qw/LoadFile/;
use DateTime;

has 'base_path'    => (is => 'ro', isa => 'Str',      required   => 1);
has 'zonefile'     => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'reminderfile' => (is => 'ro', isa => 'Str',      lazy_build => 1);
has 'zones'        => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
has 'zonehash'     => (is => 'ro', isa => 'HashRef',  lazy_build => 1);
has 'reminderhash' => (is => 'ro', isa => 'HashRef',  lazy_build => 1);

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
        my $dt = DateTime->new(year => $1, month => $2, day => $3);
        next if $now > $dt->epoch;
        return $d;
    }
    return "N/A";
}

sub reminders {
    my $self = shift;
    my $zone = shift;

    return [ keys %{ $self->reminderhash } ];
}

sub _build_zones {
    my $self = shift;
    return [sort {$a cmp $b} keys %{ $self->zonehash }];
}

sub _build_zonehash     { shift->_load_file('zone') }
sub _build_reminderhash { shift->_load_file('reminder') }

sub _load_file {
    my $self = shift;
    my $name = $_[0] . 'file';
    my $file = $self->$name;
    return {} unless -e $file;
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

1;
