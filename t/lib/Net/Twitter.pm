package Net::Twitter;
use Moose;

our @MESSAGES;

sub authorized { 1 }
sub access_token { 'goop' }
sub access_token_secret { 'gunk' }

sub new_direct_message {
    my $self = shift;
    push @MESSAGES, {
        to => shift,
        msg => shift,
    };
}

__PACKAGE__->meta->make_immutable;
1;
