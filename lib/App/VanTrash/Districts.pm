package App::VanTrash::Districts;
use Moose;
use namespace::clean -except => 'meta';

sub table        {'district'}
sub columns      {qw/district_id region_id name desc centre kml_file/}
sub has_sequence {1}

has 'district_id' => (is => 'rw', isa => 'Int');
has 'region_id'   => (is => 'rw', isa => 'Int');
has 'name'        => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'desc'        => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'centre'      => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'kml_file'    => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);

with 'App::VanTrash::Collection';

__PACKAGE__->meta->make_immutable;
1;
