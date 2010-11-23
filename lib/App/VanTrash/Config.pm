package App::VanTrash::Config;
use MooseX::Singleton;
use YAML;
use namespace::clean -except => 'meta';

has 'config_file' => (is => 'ro', isa => 'Str',     lazy_build => 1);
has 'config_hash' => (is => 'rw', isa => 'HashRef', lazy_build => 1);
has 'timestamp'   => (is => 'rw', isa => 'Int', default => 0);

sub _build_config_file {
    $ENV{VANTRASH_DEV_ENV} ? './etc/vantrash.yaml' : '/etc/vantrash.yaml';
}

sub _build_config_hash {
    my $self = shift;
    $self->_load_config;
}

sub _config_timestamp {
    my $self = shift;
    return (stat($self->config_file))[9];
}

sub _load_config {
    my $self = shift;
    $self->timestamp( $self->_config_timestamp );
    return YAML::LoadFile($self->config_file);
}

sub base_url {
    my $self = shift;
    return $self->config_hash->{base_url} || 'http://vantrash.ca';
}

sub Value {
    my $self = shift;
    my $key = shift;

    if ($self->_config_timestamp > $self->timestamp) {
        warn "Detected the config changed - reloading ...\n";
        $self->config_hash( $self->_load_config );
    }

    return $self->config_hash->{$key};
}

__PACKAGE__->meta->make_immutable;
1;
