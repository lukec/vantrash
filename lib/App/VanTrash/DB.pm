package App::VanTrash::DB;
use Moose;
use KiokuDB;
use KiokuDB::Backend::Files;
use namespace::clean -except => 'meta';
use YAML qw/LoadFile/;

has 'base_path' => (is => 'ro', isa => 'Str', required => 1);
has 'db' => (
    is => 'ro',
    isa => 'KiokuDB',
    lazy_build => 1,
    handles => [qw/store insert delete lookup new_scope update/],
);
 
sub _build_db {
    my $self = shift;
    my $db = KiokuDB->new(
        create => 1,
        backend => KiokuDB::Backend::Files->new(
            dir => $self->base_path . '/data',
            serializer => 'yaml',
        ),
    );
}

1;

