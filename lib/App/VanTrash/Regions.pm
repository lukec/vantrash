package App::VanTrash::Regions;
use Moose;
use namespace::clean -except => 'meta';

sub table { 'region' };
sub columns { qw/region_id name desc centre kml_file/ }
sub has_sequence { 1 }

with 'App::VanTrash::Collection';

__PACKAGE__->meta->make_immutable;

package App::VanTrash::Region;
use Moose;
use namespace::clean -except => 'meta';

has 'region_id' => (is => 'rw', isa => 'Int');
has 'name'      => (is => 'ro', isa => 'Str', required => 1);
has 'desc'      => (is => 'ro', isa => 'Str', required => 1);
has 'centre'    => (is => 'ro', isa => 'Str', required => 1);
has 'kml_file'  => (is => 'ro', isa => 'Str', required => 1);

__PACKAGE__->meta->make_immutable;
1;
