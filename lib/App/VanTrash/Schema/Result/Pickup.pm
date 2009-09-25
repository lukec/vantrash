package App::VanTrash::Schema::Result::Pickup;
use base qw/DBIx::Class/;
use Moose;
use MooseX::Types::Common::String qw/NonEmptySimpleStr/;

has 'id' => (is => 'ro', isa => 'Int', required => 1);
has 'zone'  => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'day'  => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'flags' => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'string' => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'day_str' => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'pretty_day' => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'datetime' => (is => 'ro', isa => 'DateTime', lazy_build => 1);

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


__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('pickup');

__PACKAGE__->add_columns(
    id    => { data_type => 'integer' },
    zone  => { data_type => 'text' },
    day   => { data_type => 'text' },
    flags => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
