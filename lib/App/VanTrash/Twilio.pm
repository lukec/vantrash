package App::VanTrash::Twilio;
use MooseX::Singleton;
use WWW::Twilio::API;
use App::VanTrash::Config;
use URI::Encode qw/uri_encode/;
use namespace::clean -except => 'meta';

has 'api' => (is => 'ro', isa => 'WWW::Twilio::API', lazy_build => 1);

sub _build_api {
    my $self = shift;

    return WWW::Twilio::API->new(
        map { $_ => App::VanTrash::Config->Value('twilio_' . $_) }
            qw(AccountSid AuthToken))
        or die "Could not create a twilio!";
}

sub send_sms {
    my $self    = shift;
    my $number  = shift;
    my $message = shift;

    my $response = $self->api->POST(
        'SMS/Messages',
        From => $self->sms_from_number,
        To   => $number,
        Body => $message,
    );
    unless ($response->{code} == 201) {
        (my $comment = $response->{content}) =~ s/.+\<Message\>(.+?)\<\/Message\>.+/$1/;
        die "Could not send SMS to $number: $comment\n";
    }
    warn "Sending text message to $number\n";
}

sub voice_call {
    my $self    = shift;
    my $number  = shift;
    my $zone = shift;

    my $url = App::VanTrash::Config->base_url . '/call/notify/' . $zone;
    my $response = $self->api->POST(
        'Calls',
        Caller => $self->voice_from_number,
        Called => $number,
        Url    => $url,
    );
    unless ($response->{code} == 201) {
        (my $comment = $response->{content}) =~ s/.+\<Message\>(.+?)\<\/Message\>.+/$1/;
        die "Could not place a call to $number: $comment\n";
    }
    warn "Placing call to $number\n";
}

sub sms_from_number {
    App::VanTrash::Config->Value('twilio_from_number_sms')
        || die "twilio_from_number_voice must be set in the config file!";
}

sub voice_from_number {
    App::VanTrash::Config->Value('twilio_from_number_voice')
        || die "twilio_from_number_sms must be set in the config file!";
}

__PACKAGE__->meta->make_immutable;
1;
