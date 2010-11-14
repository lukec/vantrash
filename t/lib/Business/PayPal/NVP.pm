package Business::PayPal::NVP;
use strict;
use warnings;

sub new {
    my $class = shift;
    my %p = @_;
    
    die unless $p{branch} eq 'test';
    die unless $p{test};
    die unless $p{test}{user};
    die unless $p{test}{pwd};
    die unless $p{test}{sig};

    my $self = { %p };
    bless $self, $class;
}

sub SetExpressCheckout {
    my $self = shift;
    my %p = @_;

    for my $key (qw/AMT CURRENCYCODE DESC CUSTOM L_NAME0 L_BILLINGTYPE0 
                    L_BILLINGAGREEMENTDESCRIPTION0 RETURNURL CANCELURL LANDINGPAGE/) {

        die "$key is required" unless $p{$key};
    }

    return (
        TOKEN => 'fake-paypal-token',
    );
}

1;
