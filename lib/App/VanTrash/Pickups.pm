package App::VanTrash::Pickups;
use Moose;
use namespace::clean -except => 'meta';

extends 'App::VanTrash::Collection';

sub by_zone {
    my $self = shift;
    my $zone = shift;
    return [
        map { $_->to_hash } $self->_rs->search(
                { zone     => $zone },
                { order_by => { -asc => 'day' } },
            )->all
    ];
}

sub by_day {
    my $self = shift;
    my $zone = shift;
    my $day  = shift;
    return $self->_rs->search( { zone => $zone, day => $day } )->first;
}

__PACKAGE__->meta->make_immutable;
1;
