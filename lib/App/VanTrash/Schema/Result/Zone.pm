package App::VanTrash::Schema::Result::Zone;
use base qw/DBIx::Class/;
use Moose;
use MooseX::Types::Common::String qw/NonEmptySimpleStr/;

has 'name'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'area'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'desc'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'colour' => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_() } qw/name area desc colour/
    };
}

sub uri {
    my $self = shift;
    return '/zones/' . $self->name;
}

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('zone');

__PACKAGE__->add_columns(
    name       => { data_type => 'text' },
    desc       => { data_type => 'text' },
    area       => { data_type => 'text' },
    colour      => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('name');

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
