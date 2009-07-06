package App::VanTrash::ModPerl;
use Mouse; # or use Moose or use Any::Moose
extends 'HTTP::Engine::Interface::ModPerl';
use App::VanTrash::Controller;

sub create_engine {
    my($class, $r, $context_key) = @_;
    
    App::VanTrash::Controller->new(
        http_module => 'ModPerl',
        base_path   => '/var/www/vantrash',
    )->engine;
}

1;
