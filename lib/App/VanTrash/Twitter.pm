package App::VanTrash::Twitter;
use MooseX::Singleton;
use YAML qw/LoadFile/;
use Net::Twitter;
use App::VanTrash::Config;
use namespace::clean -except => 'meta';

has 'twitter' => (is => 'ro', lazy_build => 1, 
    handles => ['new_direct_message', 'get_error']);

sub _build_twitter {
    my $self = shift;

    return Net::Twitter->new(
        traits => ['WrapError', 'API::REST'],
        useragent => 'VanTrash',
        map { $_ => App::VanTrash::Config->Value("twitter_$_") }
            qw/username password/
    );
}

__PACKAGE__->meta->make_immutable;
1;
