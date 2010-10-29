package App::VanTrash::Config;
use MooseX::Singleton;
use YAML;
use namespace::clean -except => 'meta';

has 'config_file' => (is => 'ro', isa => 'Str',     required   => 1);
has 'config_hash' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub _build_config_hash {
    my $self = shift;
    return YAML::LoadFile($self->config_file);
}

sub base_url {
    my $self = shift;
    return $self->config_hash->{base_url} || 'http://vantrash.ca';
}

sub Value {
    my $self = shift;
    my $key = shift;
    return $self->config_hash->{$key};
}

__PACKAGE__->meta->make_immutable;
1;
