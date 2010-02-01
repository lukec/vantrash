package App::VanTrash::Config;
use MooseX::Singleton;
use YAML;
use FindBin;

my $IS_DEV = $FindBin::Bin && $FindBin::Bin =~ m{^/(home|Users)};
my $CONFIG_FILE = $IS_DEV ? 'etc/vantrash.yaml' 
                           : '/etc/vantrash.yaml';
my $CONFIG = -e $CONFIG_FILE ? YAML::LoadFile($CONFIG_FILE) : {};

my $base_url;
sub base_url {
    my $class = shift;
    return $base_url if $base_url;

    $base_url = $CONFIG->{base_url} || 'http://vantrash.ca';
    if ($IS_DEV) {
        my $port = 1009 + $<;
        $base_url .= ":$port";
    }
    return $base_url;
}

sub dsn {
    my $class = shift;
    my $db = 'vantrash' . ($IS_DEV ? "_$ENV{USER}" : '');
    $db .= "_testing" if $ENV{HARNESS_VERSION};
    return "dbi:Pg:dbname=$db";
}

1;
