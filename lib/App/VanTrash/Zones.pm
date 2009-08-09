package App::VanTrash::Zones;
use Moose;
use namespace::clean -except => 'meta';

has 'schema' => (is => 'ro', required => 1);

sub all {
    my $self = shift;
    return [ map { $_->to_hash } $self->_rs->search()->all ];
}

sub by_area {
    my $self = shift;
    my $area = shift;
    return [ map { $_->to_hash } $self->_rs->search({area => $area})->all ];
}

sub by_name {
    my $self = shift;
    my $name = shift;
    return $self->_rs->search({name => $name})->first;
}

sub add {
    my $self = shift;
    my $zone = shift;
    my $days = delete $zone->{days};

    my $zobj = $self->_rs->create($zone);
    
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
}

sub _rs {
    my $self = shift;
    return $self->schema->resultset('Zone');
}

__PACKAGE__->meta->make_immutable;
1;
