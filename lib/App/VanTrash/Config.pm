package App::VanTrash::Config;
use MooseX::Singleton;
use YAML;
use FindBin;
use namespace::clean -except => 'meta';

warn "Loading " . Config_file();
my $CONFIG = YAML::LoadFile(Config_file());

sub Is_dev {
    $FindBin::Bin && $FindBin::Bin =~ m{^/(home|Users)}
}

sub Config_file { (Is_dev() ? '' : '/') . 'etc/vantrash.yaml' }

my $base_url;
sub base_url {
    my $class = shift;
    return $base_url if $base_url;

    $base_url = $CONFIG->{base_url} || 'http://vantrash.ca';
    if (Is_dev()) {
        my $port = 1009 + $<;
        $base_url .= ":$port";
    }
    return $base_url;
}

sub Value { $CONFIG->{$_[1]} }

1;
