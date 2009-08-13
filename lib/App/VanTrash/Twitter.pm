package App::VanTrash::Twitter;
use MooseX::Singleton;
use YAML qw/LoadFile/;
use Net::Twitter;
use namespace::clean -except => 'meta';

has 'config' => (is => 'ro', lazy_build => 1);
has 'twitter' => (is => 'ro', lazy_build => 1, handles => ['new_direct_message']);

sub _build_twitter {
    my $self = shift;

    return Net::Twitter->new(
        username => $self->config->{twitter_username},
        password => $self->config->{twitter_password},
        traits => ['WrapError', 'API::REST'],
        useragent => 'VanTrash',
    );
}

sub _build_config {
    my $self = shift;
    return LoadFile('/etc/vantrash.yaml');
}

__PACKAGE__->meta->make_immutable;
1;
