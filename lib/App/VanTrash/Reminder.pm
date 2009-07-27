package App::VanTrash::Reminder;
use Moose;

has 'id'        => (is => 'ro', isa => 'Str',  lazy_build => 1);
has 'name'      => (is => 'ro', isa => 'Str',  required   => 1);
has 'email'     => (is => 'ro', isa => 'Str',  required   => 1);
has 'offset'    => (is => 'ro', isa => 'Int',  default    => -6);
has 'confirmed' => (is => 'rw', isa => 'Bool', default    => 0);

sub _build_id {
    my $self = shift;
    my $id = lc $self->name;
    $id =~ s/\s+/_/g;
    $id =~ s/[^\w\d-]+//;

    return join '-', $self->email, $id;
}

1;
