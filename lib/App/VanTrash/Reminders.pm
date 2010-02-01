package App::VanTrash::Reminders;
use Moose;
use namespace::clean -except => 'meta';

sub table { 'reminder' }
sub columns { qw/reminder_id zone_id name email target offset confirmed
                 next_pickup_id last_notify_id confirm_hash/ }
sub has_sequence { 0 }

with 'App::VanTrash::Collection';


sub by_id   { shift->search_by(id           => @_)->first }
sub by_hash { shift->search_by(confirm_hash => @_)->first }
sub by_email { shift->search_by(email => @_)->all }

sub add {
    my $self = shift;
    my $rem = shift;

    $rem->{id} = _build_uuid('vantrash', $rem);
    $rem->{offset}        = -6 unless defined $rem->{offset};
    $rem->{confirmed}     = 0;
    $rem->{created_at}    = time;
    $rem->{last_notified} = time;
    $rem->{confirm_hash}  = _build_uuid('vantrash-confirm', $rem);

    if (!$rem->{target} or $rem->{target} =~ m/^email:/) {
        $rem->{target} = 'email:' . $rem->{email};
    }

    my $robj = $self->_rs->create($rem);
    return $robj;
}

sub _build_uuid { 
    my $namespace = shift;
    my $hash = shift;
    my $name = join '-', grep { defined } values %$hash;
    return Data::UUID->new->create_from_name_str($namespace, $name);
}

__PACKAGE__->meta->make_immutable;

package App::VanTrash::Reminder;
use Moose;
use namespace::clean -except => 'meta';

has 'reminder_id'    => (is => 'ro', isa => 'Str',  required => 1);
has 'name'           => (is => 'ro', isa => 'Str',  required => 1);
has 'email'          => (is => 'ro', isa => 'Str',  required => 1);
has 'target'         => (is => 'ro', isa => 'Str',  required => 1);
has 'zone_id'        => (is => 'ro', isa => 'Int',  required => 1);
has 'offset'         => (is => 'ro', isa => 'Int',  required => 1);
has 'confirmed'      => (is => 'rw', isa => 'Bool', required => 1);
has 'created_at'     => (is => 'ro', isa => 'Str',  required => 1);
has 'next_pickup_id' => (is => 'rw', isa => 'Int',  required => 1);
has 'last_notify_id' => (is => 'rw', isa => 'Int',  required => 1);
has 'confirm_hash'   => (is => 'ro', isa => 'Str',  required => 1);

has 'nice_name'        => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'nice_zone'        => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'confirm_url'      => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'delete_url'       => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'short_delete_url' => (is => 'ro', isa => 'Str', lazy_build => 1);
has 'zone_url'         => (is => 'ro', isa => 'Str', lazy_build => 1);

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

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_() } qw/id name email zone offset confirmed
                                     created_at next_pickup last_notified
                                     target confirm_hash/
    };
}

sub email_target { shift->target =~ m/^email:/ }
sub twitter_target { shift->target =~ m/^twitter:/ }

__PACKAGE__->meta->make_immutable;
1;
