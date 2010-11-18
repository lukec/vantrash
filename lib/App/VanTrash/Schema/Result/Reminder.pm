package App::VanTrash::Schema::Result::Reminder;
use base qw/DBIx::Class/;
use Moose;
use MooseX::Types::Common::String qw/NonEmptySimpleStr/;
use WWW::Shorten::isgd;
use Data::UUID;
use App::VanTrash::Config;
use App::VanTrash::Paypal;
use DateTime;
use DateTime::Duration;
use namespace::clean -except => 'meta';

has 'id'            => (is => 'ro', isa => 'Str',  required => 1);
has 'name'          => (is => 'ro', isa => 'Str',  required => 1);
has 'email'         => (is => 'ro', isa => 'Str',  required => 1);
has 'target'        => (is => 'ro', isa => 'Str',  required => 1);
has 'zone'          => (is => 'ro', isa => 'Str',  required => 1);
has 'offset'        => (is => 'ro', isa => 'Int',  required => 1);
has 'confirmed'     => (is => 'rw', isa => 'Bool', required => 1);
has 'created_at'    => (is => 'ro', isa => 'Int',  required => 1);
has 'next_pickup'   => (is => 'rw', isa => 'Int',  required => 1);
has 'last_notified' => (is => 'rw', isa => 'Int',  required => 1);
has 'confirm_hash'  => (is => 'ro', isa => 'Str',  required => 1);
has 'expiry'                  => (is => 'ro', isa => 'Int', default => 0);
has 'payment_period'          => (is => 'ro', isa => 'Str');
has 'subscription_profile_id' => (is => 'ro', isa => 'Str');

has 'nice_name'        => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'nice_zone'        => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'confirm_url'      => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'delete_url'       => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'short_delete_url' => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'zone_url'         => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'payment_url'      => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'expiry_date'      => (is => 'ro', isa => 'DateTime', lazy_build => 1);

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_() }
            qw/id name email zone offset confirmed created_at next_pickup
            last_notified target confirm_hash payment_period expiry/
    };
}

sub email_target { shift->target =~ m/^email:/ }
sub twitter_target { shift->target =~ m/^twitter:/ }

sub is_expired {
    my $self = shift;
    return DateTime->today > $self->expiry_date;
}

sub _build_nice_name {
    my $self = shift;
    return join('-', $self->zone, $self->email, $self->name)
        . " (" . $self->target . ")";
}

sub _build_nice_zone {
    my $self = shift;
    my $zone = $self->zone;
    $zone =~ s/(\w+)/ucfirst($1)/eg;
    return $zone;
}

sub _build_confirm_url {
    my $self = shift;
    return join '/', $self->zone_url, $self->confirm_hash, 'confirm';
}

sub _build_delete_url {
    my $self = shift;
    return join '/', $self->zone_url,  $self->id, 'delete';
}

sub _build_short_delete_url {
    my $self = shift;
    return makeashorterlink($self->delete_url);
}

sub _build_zone_url {
    my $self = shift;
    my $type = shift || 'id';
    return join '/', App::VanTrash::Config->base_url, 'zones', $self->zone, 'reminders';
}

sub _build_expiry_date {
    my $self = shift;
    return DateTime->now + DateTime::Duration->new(years => 5) unless $self->expiry;
    return DateTime->from_epoch($self->expiry);
}

sub _build_payment_url {
    my $self = shift;

    return App::VanTrash::Paypal->set_up_subscription(
        period => $self->payment_period,
        custom => $self->id,
    );
}

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('reminder');

__PACKAGE__->add_columns(
    id            => { data_type => 'text' },
    name          => { data_type => 'text' },
    email         => { data_type => 'text' },
    target        => { data_type => 'text' },
    zone          => { data_type => 'text' },
    offset        => { data_type => 'integer' },
    confirmed     => { data_type => 'boolean' },
    created_at    => { data_type => 'integer' },
    next_pickup   => { data_type => 'integer' },
    last_notified => { data_type => 'integer' },
    confirm_hash  => { data_type => 'text' },
    payment_period          => { data_type => 'text' },
    expiry                  => { data_type => 'integer' },
    subscription_profile_id => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
