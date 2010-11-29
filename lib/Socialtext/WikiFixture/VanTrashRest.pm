package Socialtext::WikiFixture::VanTrashRest;
use Moose;
use Test::More;
use JSON::XS qw(decode_json);
use JSON::Path;
use Test::HTTP;
use namespace::clean -except => 'meta';

extends 'Socialtext::WikiFixture';

has 'http' => (
    is => 'ro', isa => 'Test::HTTP', lazy_build => 1
);

sub set_scheme {
    my ($self, $var, $scheme) = @_;
    $self->{$var} =~ s{http://}{$scheme};
    diag "Set $var to $self->{$var}";
}

has 'config' => (
    is => 'ro', isa => 'App::VanTrash::Config', lazy_build => 1,
);

sub _build_config {
    App::VanTrash::Config->new(config_file => './etc/vantrash.yaml');
}

sub _build_http {
    my $self = shift;
    return Test::HTTP->new('vantrash');
};

sub _http {
    my ($self, $method, $uri, $headers, $body) = @_;
    $headers ||= [];
    $uri = "$self->{browser_url}$uri" if $uri =~ m#^/#;
    diag "$method $uri";
    $self->http->$method($uri, $headers, $body);
}

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';
    $self->_http('get', $uri, [Accept => $accept]);
}

sub post {
    my ($self, $uri, $body) = @_;
    $self->_http('post', $uri, [], $body);
}

sub code_is {
    my ($self, $code) = @_;
    $self->http->status_code_is($code);
}

sub body_is {
    my ($self, $expected) = @_;
    $self->http->body_is($expected);
}

sub body_like {
    my ($self, $regex) = @_;
    $self->http->body_like($self->quote_as_regex($regex));
}

sub header_is {
    my ($self, $header, $expected) = @_;
    $self->http->header_is($header,$expected);
}

sub get_json_path {
    my ($self, $path) = @_;
    my $body = $self->http->response->decoded_content;
    return (JSON::Path->new($path)->values($body))[0];
}

sub json_path_is {
    my ($self, $path, $expected) = @_;
    is $self->get_json_path($path), $expected,
        "json-path-is $path"
}

sub json_path_like {
    my ($self, $path, $expected) = @_;
    like $self->get_json_path($path), $self->quote_as_regex($expected),
        "json-path-like $path"
}

sub text_like {
    my $self = shift;
    my $text = shift;
    my $regex = shift;
    like $text, $regex, 'text_like';
}

sub text_unlike {
    my $self = shift;
    my $text = shift;
    my $regex = shift;
    unlike $text, $regex, 'text_like';
}

sub exec_regex {
    my $self = shift;
    my $name = shift;
    my $content = shift;
    my $regex = $self->quote_as_regex(shift || '');
    if ($content =~ $regex and $1) {
        $self->{$name} = $1;
        diag "Set $name to '$1'";
    }
    else {
        die "Could not set exec '$regex' on '$content'";
    }
}

# Email stuff

sub wait_for_email_ok {
    my ($self, $email_address) = @_;
    require Mail::POP3Client;

    my $pop = new Mail::POP3Client(
        USER     => $self->config->Value('tester_username'),
        PASSWORD => $self->config->Value('tester_password'),
        HOST     => "pop.gmail.com",
        USESSL   => 1,
    );

    $self->{email_body} = undef;

    for (0 .. 10) {
        $pop->Connect() >= 0 || die $pop->Message();
        for my $i (1 .. $pop->Count()) {
            for ($pop->Head($i)) {
                if (/^To:\s+(.*)/i and $1 eq $email_address) {
                    die "Multiple emails found!" if $self->{email_body};
                    $self->{email_body} = scalar $pop->Body($i);
                }
            }
        }
        $pop->Close();
        last if $self->{email_body};
        diag "Waiting for email...";
        sleep 1;
    }

    $self->{email_body} =~ s{\r}{}g;

    ok $self->{email_body}, 'wait_for_email_ok';
}

# VanTrash stuff

sub _api_get_next_pickup_date {
    my ($self, $zone) = @_;
    $self->get("/zones/$zone/nextpickup.json");
    my $data = decode_json($self->http->response->content);
    (my $date = $data->{'next'}[0]) =~ s{ Y$}{};
    my ($y, $m, $d) = split '-', $date;
    my $dt = DateTime->new(year => $y, month => $m, day=> $d);
    return sprintf(
        "%s %s %d %d", $dt->day_abbr, $dt->month_abbr, $dt->day, $dt->year
    );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
