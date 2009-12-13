package App::VanTrash::Config;
use base 'Exporter';
use YAML;

my $CONFIG_FILE => '/etc/vantrash.yaml';
my $CONFIG = -e $CONFIG_FILE ? YAML::LoadFile($CONFIG_FILE) : {};

my $base_url;
sub base_url {
    my $class = shift;
    return $base_url if $base_url;

    $base_url = $CONFIG->{base_url} || 'http://vantrash.ca';
    if ($ENV{DEV_ENV}) {
        my $port = 1009 + $<;
        $base_url .= ":$port";
    }
    return $base_url;
}

1;
