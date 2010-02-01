package App::VanTrash::Schema::Result::Region;
use base qw/DBIx::Class/;
use Moose;
use MooseX::Types::Common::String qw/NonEmptySimpleStr/;

has 'region_id' => (is => 'rw', isa => 'Int');
has 'name'      => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'desc'      => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'centre'    => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'kml_file'  => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_() } qw/region_id name desc centre kml_file/
    };
}

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('region');

__PACKAGE__->add_columns(
    region_id => { data_type => 'integer' },
    name      => { data_type => 'text' },
    desc      => { data_type => 'text' },
    centre    => { data_type => 'text' },
    kml_file  => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('region_id');

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
