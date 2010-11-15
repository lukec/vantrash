package WWW::Twilio::API;
use Moose;

sub POST {
    return { code => 201 }
}

__PACKAGE__->meta->make_immutable;
1;
