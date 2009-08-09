package App::VanTrash::Areas;
use Moose;
use namespace::clean -except => 'meta';

has 'schema' => (is => 'ro', required => 1);

sub all {
    my $self = shift;
    return [ map { $_->to_hash } $self->_rs->search()->all ];
}

sub by_name {
    my $self = shift;
    my $name = shift;
    return $self->_rs->search({name => $name})->first;
}

sub add {
    my $self = shift;
    return $self->_rs->create(@_);
}

sub _rs {
    my $self = shift;
    return $self->schema->resultset('Area');
}

__PACKAGE__->meta->make_immutable;
1;
