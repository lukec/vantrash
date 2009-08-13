package Net::Twitter;
use Moose;

our @MESSAGES;

sub new_direct_message {
    my $self = shift;
    push @MESSAGES, {
        to => shift,
        msg => shift,
    };
}

__PACKAGE__->meta->make_immutable;
1;
