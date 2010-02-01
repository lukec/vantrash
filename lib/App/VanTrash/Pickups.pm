package App::VanTrash::Pickups;
use MooseX::Singleton;
use namespace::clean -except => 'meta';

sub table        {'pickup'}
sub columns      {qw/pickup_id zone_id day flags/}
sub has_sequence {1}

with 'App::VanTrash::Collection';

__PACKAGE__->meta->make_immutable;

package App::VanTrash::Pickup;
use Moose;
use DateTime;
use namespace::clean -except => 'meta';

has 'pickup_id'  => (is => 'ro', isa => 'Int',               required   => 1);
has 'zone_id'    => (is => 'ro', isa => 'Int',               required   => 1);
has 'zone'       => (is => 'ro', isa => 'Object',            lazy_build => 1);
has 'day'        => (is => 'ro', isa => 'NonEmptySimpleStr', required   => 1);
has 'flags'      => (is => 'ro', isa => 'NonEmptySimpleStr', required   => 1);
has 'string'     => (is => 'ro', isa => 'Str',               lazy_build => 1);
has 'day_str'    => (is => 'ro', isa => 'Str',               lazy_build => 1);
has 'pretty_day' => (is => 'ro', isa => 'Str',               lazy_build => 1);
has 'datetime'   => (is => 'ro', isa => 'DateTime',          lazy_build => 1);

sub by_zone {
    my $self = shift;
    my $zone = shift;
    return [
        map { $_->to_hash } $self->_rs->search(
                { zone     => $zone },
                { order_by => { -asc => 'day' } },
            )->all
    ];
}

sub by_epoch {
    my $self = shift;
    my $zone = shift;
    my $epoch  = shift;

    my $dt = DateTime->from_epoch(epoch => $epoch);
    my $day = $dt->ymd;
    return $self->_rs->search( { zone => $zone, day => $day } )->first;
}

sub to_hash {
    my $self = shift;
    my ($year, $month, $day) = split '-', $self->day;
    return {
        year => $year,
        month => $month,
        day => $day,
        zone => $self->zone,
        string => $self->string,
        flags => $self->flags,
    };
}

sub _build_string {
    my $self = shift;
    return join ' ', $self->day, ($self->flags ? $self->flags : ());
}

sub _build_pretty_day {
    my $self = shift;
    my $dt = $self->datetime;
    return $dt->day_name . ', ' . $dt->month_name . ' ' . $dt->day;
}

sub _build_datetime {
    my $self = shift;
    my $hash = $self->to_hash;
    return DateTime->new( map { $_ => $hash->{$_} } qw/year month day/ );
}

__PACKAGE__->meta->make_immutable;
1;
