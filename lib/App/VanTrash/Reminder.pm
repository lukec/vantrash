package App::VanTrash::Reminder;
use Moose;
use Digest::SHA1 qw/sha1_hex/;

has 'name'        => (is => 'ro', isa => 'Str',  required   => 1);
has 'email'       => (is => 'ro', isa => 'Str',  required   => 1);
has 'zone'        => (is => 'ro', isa => 'Str',  required   => 1);
has 'offset'      => (is => 'ro', isa => 'Int',  default    => -6);
has 'confirmed'   => (is => 'rw', isa => 'Bool', default    => 0);
has 'confirm_url' => (is => 'rw', isa => 'Str',  lazy_build => 1);
has 'id'          =>
    (is => 'ro', isa => 'Str', required => 1, lazy_build => 1);
has 'created_at' =>
    (is => 'ro', isa => 'Int', required => 1, lazy_build => 1);
has 'confirm_hash' =>
    (is => 'ro', isa => 'Int', required => 1, lazy_build => 1);

sub _build_id {
    my $self = shift;

    return sha1_hex($self->zone . $self->email . $self->name);
}

sub _build_confirm_url {
    my $self = shift;
    return 'http://vantrash.ca/zones/' . $self->zone
        . '/reminders/' . $self->id . '/confirm';
}

sub _build_created_at {
    return time();
}

sub _build_confirm_hash {
    my $self = shift;
    return sha1_hex($self->id . $self->created_at);
}

1;
