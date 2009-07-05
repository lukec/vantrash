package App::VanTrash::Model;
use Moose;
use YAML qw/LoadFile/;
use DateTime;

has 'file' => (is => 'ro', isa => 'Str', default => 'trash-zone-times.yaml');
has 'zones' => (is => 'ro', lazy_build => 1);
has 'hash' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub days {
    my $self = shift;
    my $zone = shift;
    return [sort {$a cmp $b} @{ $self->hash->{$zone} }];
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

sub _build_zones {
    my $self = shift;
    return [sort {$a cmp $b} keys %{ $self->hash }];
}

sub _build_hash {
    my $self = shift;
    return LoadFile($self->file);
}

1;
