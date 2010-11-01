#!perl
use Plack::Builder;
use App::VanTrash::CallController;
use App::VanTrash::Controller;
use App::VanTrash::Config;

# Create the singleton config object
App::VanTrash::Config->new(config_file => '/etc/vantrash.yaml');

my $root = '/var/www/vantrash';
my $log = '/var/log/vantrash.log';
builder {
    enable "Plack::Middleware::AccessLog::Timed",
            format => "%h %l %u %t \"%r\" %>s %b %D";

    mount "/call" => sub {
        App::VanTrash::CallController->new(
            base_path => $root,
            log_file => $log,
        )->run(@_);
    };

    mount "/" => sub {
        App::VanTrash::Controller->new(
            base_path => $root,
            log_file => $log,
        )->run(@_);
    }
};

