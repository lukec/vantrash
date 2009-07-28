package t::VanTrash;
use Moose;
use namespace::clean -except => 'meta';

$ENV{VT_EMAIL} = "/tmp/email.$$";
END { unlink $ENV{VT_EMAIL} if $ENV{VT_EMAIL} }

__PACKAGE__->meta->make_immutable;
1;
