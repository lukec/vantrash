package App::VanTrash::Paypal;
use MooseX::Singleton;
use Business::PayPal::NVP;
use App::VanTrash::Config;
use namespace::clean -except => 'meta';

# Website Payments Pro and Express Checkout API Reference -
# https://www.x.com/docs/DOC-1372

has 'api' => (is => 'ro', isa => 'Business::PayPal::NVP', lazy_build => 1);

sub _build_api {
    my $self = shift;

    my $config = App::VanTrash::Config->new;
    my $branch = $config->Value('paypal_branch') or die "No paypal branch defined!";
    return Business::PayPal::NVP->new(
        branch => $branch,
        $branch => {
            user => $config->Value('paypal_user'),
            pwd => $config->Value('paypal_pwd'),
            sig => $config->Value('paypal_sig'),
        },
    );
}

sub set_up_subscription {
    my $self = shift;
    my %opts = @_;

    die "Invalid period - '$opts{period}'" unless $opts{period} =~ m/^(?:month|year)$/;
    die "Custom is required" unless $opts{custom};

    my %period_opts = (
        month => {
            amount => '1.50',
            name => 'Monthly VanTrash Subscription',
            desc => '$1.50 per month for VanTrash notifications',
        },
        year => {
            amount => '15.00',
            name => 'Annual VanTrash Subscription',
            desc => '$15.00 per year for VanTrash notifications',
        },
    );
    my $p = $period_opts{ $opts{period}};
    
    # SetExpressCheckout - https://www.x.com/docs/DOC-1208
    my $base_url = App::VanTrash::Config->base_url;
    my %resp = $self->api->SetExpressCheckout(
        AMT => $p->{amount},
        CURRENCYCODE => 'CAD',
        DESC => 'Vantrash Garbage Reminder Service',
        CUSTOM => $opts{custom},
        L_NAME0 => $p->{name},
        L_BILLINGTYPE0 => 'RecurringPayments',
        L_BILLINGAGREEMENTDESCRIPTION0 => $p->{desc},
        RETURNURL => "$base_url/billing/proceed",
        CANCELURL => "$base_url/billing/cancel",
        LANDINGPAGE => 'Billing',
    ) or do {
        warn "Error! " . join("\n", $self->api->errors);
        die "Could not create a VanTrash subscription payment. Try again later.\n";
    };

    my $paypal_base_url = 'https://www.paypal.com';
    if (App::VanTrash::Config->Value('paypal_branch') eq 'test') {
        $paypal_base_url = 'https://www.sandbox.paypal.com';
    }

    return "$paypal_base_url/cgi-bin/webscr?cmd=_express-checkout&token=$resp{TOKEN}";
}

__PACKAGE__->meta->make_immutable;
1;
