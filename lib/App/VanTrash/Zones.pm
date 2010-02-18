package App::VanTrash::Zones;
use Moose;
use namespace::clean -except => 'meta';

extends 'App::VanTrash::Collection';

sub by_area { [ shift->search_by(area => @_)->all ] }

around 'add' => sub {
    my $orig = shift;
    my $self = shift;
    my $zone = shift;
    my $days = delete $zone->{days};
    my $name = $zone->{name};

    my $zobj;
    if ($zobj = $self->_rs->search({name => $name})) {
        warn "Looks like $name already exists\n";
    }
    else {
        warn "Creating zone $name\n";
        $zobj = $orig->($self, $zone);
    }
    
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
1;
