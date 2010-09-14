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

    my $nt = Net::Twitter->new(
        traits    => [ 'WrapError', 'API::REST', 'OAuth' ],
        useragent => 'VanTrash',
        consumer_key => 
            App::VanTrash::Config->Value("twitter_consumer_key"),
        consumer_secret =>
            App::VanTrash::Config->Value("twitter_consumer_secret"),
    );

    my $access_token = App::VanTrash::Config->Value('twitter_oauth_token');
    my $token_secret
        = App::VanTrash::Config->Value('twitter_oauth_token_secret');
    if ($access_token && $token_secret) {
        $nt->access_token($access_token);
        $nt->access_token_secret($token_secret);
    }
    unless ($nt->authorized) {
        die "Twitter OAuth client is not authorized. Update Vantrash config.\n";
    }
    return $nt;
}

__PACKAGE__->meta->make_immutable;
1;
