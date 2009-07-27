package App::VanTrash::Reminder;
use Moose;
use Digest::SHA1 qw/sha1_hex/;

has 'name'        => (is => 'ro', isa => 'Str',  required   => 1);
has 'email'       => (is => 'ro', isa => 'Str',  required   => 1);
has 'zone'        => (is => 'ro', isa => 'Str',  required   => 1);
has 'offset'      => (is => 'ro', isa => 'Int',  default    => -6);
has 'confirmed'   => (is => 'rw', isa => 'Bool', default    => 0);
has 'confirm_url' => (is => 'ro', isa => 'Str',  lazy_build => 1);
has 'delete_url'  => (is => 'ro', isa => 'Str',  lazy_build => 1);
has 'base_url'    => (is => 'ro', isa => 'Str',  lazy_build => 1);
has 'id'          =>
    (is => 'ro', isa => 'Str', required => 1, lazy_build => 1);
has 'created_at' =>
    (is => 'ro', isa => 'Int', required => 1, lazy_build => 1);
has 'confirm_hash' =>
    (is => 'ro', isa => 'Str', required => 1, lazy_build => 1);
has 'last_notified' => (is => 'rw', isa => 'Int', default => 0);

sub _build_id {
    my $self = shift;

    return sha1_hex($self->zone . $self->email . $self->name);
}

sub _build_confirm_url {
    my $self = shift;
    return $self->base_url . $self->confirm_hash . '/confirm';
}

sub _build_delete_url {
    my $self = shift;
    return $self->base_url . $self->id . '/delete';
}

sub _build_base_url {
    my $self = shift;
    my $type = shift || 'id';
    return 'http://vantrash.ca/zones/' . $self->zone . '/reminders/';
}

sub _build_created_at {
    return time();
}

sub _build_confirm_hash {
    my $self = shift;
    return sha1_hex($self->id . $self->created_at);
}

1;
