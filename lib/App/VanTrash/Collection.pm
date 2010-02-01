package App::VanTrash::Collection;
use Moose::Role;
use App::VanTrash::DB;

has 'db' => (is => 'ro', isa => 'Object', lazy_build => 1);

requires 'table';
requires 'columns';
requires 'has_sequence';

sub all {
    my $self = shift;
    my $want_objects = shift;
    my $sth = $self->db->sql_execute('SELECT * FROM ' . $self->table);

    my $results = $sth->fetchall_arrayref({});
    return [ map { $self->_new_instance($_) } @$results ];
    
}

sub _new_instance {
    my $self = shift;
    (my $instance_class = ref($self)) =~ s/s$//;
    return $instance_class->new(@_);
}

sub sequence {
    my $self = shift;
    return unless $self->has_sequence;
    return $self->table . '_seq';
}

sub by_name { 
    'not implemented'
}

sub add {
    my $self = shift;
    my $thingy = shift;

    if (my $seq = $self->sequence) {
        my $id = $self->db->sql_singlevalue("SELECT nextval('$seq')");
        $thingy->{$self->table . '_id'} = $id;
    }

    my @all_columns = $self->columns;
    my (@cols, @vals);
    for my $c (@all_columns) {
        next unless defined $thingy->{$c};
        push @cols, ($c eq 'desc' ? '"desc"' : $c);
        push @vals, $thingy->{$c};
    }

    $self->db->sql_execute(
        "INSERT INTO " . $self->table . " ("
            . join(', ', @cols) . ') VALUES ('
            . join(', ', map { '?' } @vals) . ')',
        @vals,
    );
    return $self->_new_instance($thingy);
}

sub search_by {
    my $self = shift;
    my $key  = shift;
    my $value = shift;

    die 'not implemented';
}

sub _build_db { App::VanTrash::DB->new }

1;
