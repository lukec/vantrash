package App::VanTrash::Pickups;
use Moose;
use DateTime;
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

sub by_epoch {
    my $self = shift;
    my $zone = shift;
    my $epoch  = shift;

    my $dt = DateTime->from_epoch(epoch => $epoch);
    my $day = $dt->ymd;
    return $self->_rs->search( { zone => $zone, day => $day } )->first;
}

__PACKAGE__->meta->make_immutable;
1;
