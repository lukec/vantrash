package App::VanTrash::Pickups;
use Moose;
use namespace::clean -except => 'meta';

has 'schema' => (is => 'ro', required => 1);

sub all {
    my $self = shift;
    return [ map { $_->to_hash } $self->_rs->search()->all ];
}

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

sub _rs {
    my $self = shift;
    return $self->schema->resultset('Pickup');
}

__PACKAGE__->meta->make_immutable;
1;
