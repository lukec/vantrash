package Business::PayPal::NVP;
use strict;
use warnings;

our $CUSTOM;
our %CHECKOUT;

sub new {
    my $class = shift;
    my %p = @_;
    
    require Data::Dumper;
    die Data::Dumper::Dumper(\%p) unless $p{test};
    die Data::Dumper::Dumper(\%p) unless $p{test}{user};
    die Data::Dumper::Dumper(\%p) unless $p{test}{pwd};
    die Data::Dumper::Dumper(\%p) unless $p{test}{sig};

    my $self = { %p };
    bless $self, $class;
}

sub SetExpressCheckout {
    my $self = shift;
    my %p = @_;

    for my $key (qw/AMT CURRENCYCODE DESC CUSTOM L_NAME0 L_BILLINGTYPE0 
                    L_BILLINGAGREEMENTDESCRIPTION0 RETURNURL CANCELURL LANDINGPAGE/) {
        next if $CHECKOUT{$key} = $p{$key};
        warn "$key is required";
        die "$key is required";
    }
    $CUSTOM = $p{CUSTOM};

    return (
        TOKEN => 'fake-paypal-token',
    );
}

sub GetExpressCheckoutDetails {
    my $self = shift;
    return (
        ACK => 'Success',
        CUSTOM => $CUSTOM,
        BILLINGAGREEMENTACCEPTEDSTATUS => 1,
    );
}

sub CreateRecurringPaymentsProfile {
    my $self = shift;
    return (ACK => 'Success');
}

1;
