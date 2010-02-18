package App::VanTrash::Collection;
use Moose;
use Carp qw/croak/;
use namespace::clean -except => 'meta';

has 'schema' => (is => 'ro', required => 1);

sub all {
    my $self = shift;
    my $objects = shift;
    return [ map { $objects ? $_ : $_->to_hash } $self->_rs->search()->all ];
}

sub by_name { shift->search_by(name => @_)->first }

sub add {
    my $self = shift;
    my $res = eval {  $self->_rs->create(@_) };
    croak "Could not add a new " . ref($self) if $@;
    return $res;
}

sub search_by {
    my $self = shift;
    my $key  = shift;
    my $value = shift;

    return $self->_rs->search({$key => $value});
}

sub _rs {
    my $self = shift;
    (my $class = ref($self)) =~ s/.+::(.+)s$/$1/;
    return $self->schema->resultset($class);
}

__PACKAGE__->meta->make_immutable;
1;
