package App::VanTrash::ReminderManager;
use Moose;
use namespace::clean -except => 'meta';

has 'db' => (is => 'rw', required => 1);
has 'db_scope' => (is => 'rw');
has 'need_confirmation' =>
    (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'reminders' => (is => 'rw', isa => 'HashRef', default => sub { {} });

sub load_or_create {
    my $class = shift;
    my $obj   = $class->new(@_);
    my $scope = $obj->db->new_scope;

    my $existing = eval { $obj->db->lookup('reminders') };
    if ($existing) {
        $existing->db($obj->db);
        $existing->db_scope($scope);
        return $existing;
    }

    $obj->save('create');
    return $obj;
}

# We don't want to save the DB and scope.
sub save {
    my $self       = shift;
    my $first_time = shift;
    my $db         = $self->db;
    my $scope      = $self->db_scope;
    my $new_scope  = $db->new_scope;

    $self->db('');
    $self->db_scope('');

    if ($first_time) {
        $db->insert('reminders' => $self);
    }
    else {
        $db->store($self);
    }

    $self->db($db);
    $self->db_scope($new_scope);
}

sub all {
    my $self = shift;
    return [ values %{ $self->reminders } ];
}

sub by_id {
    my $self = shift;
    my $id   = shift;

    return $self->reminders->{$id};
}

sub by_hash {
    my $self = shift;
    my $hash = shift;

    return $self->need_confirmation->{$hash};
}

sub insert {
    my $self = shift;
    my $rem  = shift;

    if ($self->reminders->{$rem->id}) {
        die "A reminder for this zone with this ID already exists!";
    }
    unless ($rem->next_pickup) {
        die "next_pickup must be set before insert!";
    }

    $self->reminders->{$rem->id} = $rem;
    $self->need_confirmation->{$rem->confirm_hash} = $rem;
    $self->save;
}

sub confirm {
    my $self = shift;
    my $rem  = shift;

    $rem->confirmed(1);
    delete $self->need_confirmation->{$rem->confirm_hash};
    $self->save;
}

sub delete {
    my $self = shift;
    my $rem  = shift;

    delete $self->reminders->{$rem->id};
    delete $self->need_confirmation->{$rem->confirm_hash};
    $self->save;
}

__PACKAGE__->meta->make_immutable;
1;
