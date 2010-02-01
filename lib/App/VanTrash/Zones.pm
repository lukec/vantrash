package App::VanTrash::Zones;
use MooseX::Singleton;
use namespace::clean -except => 'meta';

sub table        {'zone'}
sub columns      {qw/zone_id name district_id area desc colour/}
sub has_sequence {1}

with 'App::VanTrash::Collection';

sub by_area { [ shift->search_by(area => @_)->all ] }

around 'add' => sub {
    my $orig = shift;
    my $self = shift;
    my $zone = shift;
    my $days = delete $zone->{days};

    my $zobj = $orig->($self, $zone);
    
    for my $day_str (@$days) {
        unless ($day_str =~ m/^([\d-]+)(?:\s+(\w+))?$/) {
            warn "Couldn't parse $day_str!";
            next;
        }
        my ($day, $flags) = ($1, $2);
        $self->schema->resultset('Pickup')->create({
                zone => $zobj->name,
                day => $day,
                flags => $flags || '',
            },
        );
    }
    return $zobj;
};

__PACKAGE__->meta->make_immutable;

package App::VanTrash::Zone;
use Moose;
use namespace::clean -except => 'meta';

has 'zone_id' => (is => 'ro', isa => 'Int');
has 'name'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'area'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'desc'   => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);
has 'colour' => (is => 'ro', isa => 'NonEmptySimpleStr', required => 1);

sub uri {
    my $self = shift;
    return '/zones/' . $self->name;
}

__PACKAGE__->meta->make_immutable;
1;
