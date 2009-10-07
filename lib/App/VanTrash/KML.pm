package App::VanTrash::KML;
use Moose;
use XML::XPath;
use XML::XPath::XMLParser;
use Math::Polygon;
use namespace::clean -except => 'meta';

has 'filename' => (is => 'ro', isa => 'Str');
has 'xpath' => (is => 'ro', isa => 'XML::XPath', lazy_build => 1);
has 'polygons' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1, auto_deref => 1
);

sub _build_xpath {
    my $self = shift;
    return XML::XPath->new(filename => $self->filename);
}

sub _build_polygons {
    my $self = shift;
    my @polygons;
    my $results = $self->xpath->find('//Placemark');
    for my $node ($results->get_nodelist) {
        my %poly;
        $poly{name} = $self->xpath->find('name', $node)->shift->string_value;
        my $coords = $self->xpath->find('coordinates', $node);
        if ($coords->isa('XML::XPath::NodeSet')) {
            my $node = $results->shift;
            my @points;
            for my $coord (split /\s*\n\s*/, $node->string_value) {
                my ($lng,$lat) = split ',', $coord;
                if ($lat and $lng) {
                    push @points, [$lat,$lng];
                }
            }
            $poly{shape} = Math::Polygon->new(@points);
        }
        push @polygons, \%poly;
    }
    return \@polygons;
}

sub find_zone_for_latlng {
    my $self = shift;
    my $lat = shift;
    my $lng = shift;
    for my $polygon ($self->polygons) {
        if ($polygon->{shape} and $polygon->{shape}->contains([$lat,$lng])) {
            return $polygon->{name};
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;
