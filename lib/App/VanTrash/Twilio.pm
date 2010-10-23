package App::VanTrash::Twilio;
use MooseX::Singleton;
use WWW::Twilio::API;
use App::VanTrash::Config;
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
        From => App::VanTrash::Config->Value('twilio_from_number'),
        To   => $number,
        Body => $message,
    );
    unless ($response->{code} == 201) {
        (my $comment = $response->{content}) =~ s/.+\<Message\>(.+?)\<\/Message\>.+/$1/;
        die "Could not send SMS to $number: $comment\n";
    }
}

__PACKAGE__->meta->make_immutable;
1;
