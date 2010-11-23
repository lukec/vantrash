package Business::PayPal::IPN;
use strict;
use warnings;
use unmocked 'Data::Dumper';

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

sub dump {
    return Dumper $_[0];
}


1;
