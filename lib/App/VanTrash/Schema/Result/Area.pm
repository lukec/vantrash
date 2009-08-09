package App::VanTrash::Schema::Result::Area;
use base qw/DBIx::Class/;
use Moose;
use MooseX::Types::Common::String qw/NonEmptySimpleStr/;

has 'name'  => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'desc'  => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'centre' => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_() } qw/name desc centre/
    };
}

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('area');

__PACKAGE__->add_columns(
    name   => { data_type => 'text' },
    desc   => { data_type => 'text' },
    centre => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('name');

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
