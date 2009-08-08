package App::VanTrash::ModPerl;
use Moose;
extends 'HTTP::Engine::Interface::ModPerl';
use App::VanTrash::Controller;
use namespace::clean -except => 'meta';

sub create_engine {
    my($class, $r, $context_key) = @_;
    
    App::VanTrash::Controller->new(
        http_module => 'ModPerl',
        base_path   => '/var/www/vantrash',
    )->engine;
}

__PACKAGE__->meta->make_immutable;
1;
