#!perl

# This is the development psgi file

use Plack::Builder;
use lib "lib";
use App::VanTrash::CallController;
use App::VanTrash::Controller;
use App::VanTrash::Config;

App::VanTrash::Config->new(config_file => 'etc/vantrash.yaml');

builder {
    enable 'Debug', panels => [qw(
        Environment Response Memory Timer 
        Parameters Session
    )];
    enable 'Debug::DBIProfile', profile => 2;
    enable 'Debug::DBITrace';

    enable "Plack::Middleware::Static",
           path => qr{^/(robots\.txt|zones\.kml|images)}, 
           root => './static/';
    enable "Plack::Middleware::Static",
           path => sub { s!^/(javascript|css)/(?:\d+\.\d+)/(.+)!/$1/$2! },
           root => './static/';

    mount "/call" => sub {
        App::VanTrash::CallController->new(
            base_path => ".",
            log_file => 'vantrash.log',
        )->run(@_);
    };

    mount "/" => sub {
        local $ENV{VANTRASH_DEV_ENV} = 1;
        App::VanTrash::Controller->new(
            base_path => ".",
            log_file => 'vantrash.log',
        )->run(@_);
    }
};

