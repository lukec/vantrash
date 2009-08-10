package App::VanTrash::Areas;
use Moose;
use namespace::clean -except => 'meta';

extends 'App::VanTrash::Collection';

__PACKAGE__->meta->make_immutable;
1;
