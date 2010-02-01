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
