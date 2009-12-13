package App::VanTrash::Config;
use base 'Exporter';
use YAML;
use FindBin;

my $CONFIG_FILE => '/etc/vantrash.yaml';
my $CONFIG = -e $CONFIG_FILE ? YAML::LoadFile($CONFIG_FILE) : {};
my $IS_DEV = $FindBin::Bin && $FindBin::Bin =~ m{^/home};

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

1;
