package Business::PayPal::IPN;
use strict;
use warnings;

our %TEST_DATA;

sub new {
    my $class = shift;
    my %p = @_;
    
    my $self = { %p };
    bless $self, $class;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/.+:://;
    return $TEST_DATA{$name};
}

sub vars { %TEST_DATA }



1;
