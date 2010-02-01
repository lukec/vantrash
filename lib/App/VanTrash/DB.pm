package App::VanTrash::DB;
use MooseX::Singleton;
use App::VanTrash::Config;
use DBI;
use namespace::clean -except => 'meta';

has 'dbh' => (is => 'rw', isa => 'Object', lazy_build => 1);

sub sql_execute {
    my $class = shift;
    my $sql   = shift;
    my @bind  = @_;
    my $dbh   = $class->dbh;
    
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind) || die "execute failed: " . $sth->errstr . "\n";
    return $sth;
}

sub sql_singlevalue {
    my ( $class, $statement, @bindings ) = @_;
 
    my $sth = $class->sql_execute($statement, @bindings);
    my $value;
    $sth->bind_columns(undef, \$value);
    $sth->fetch();
    $sth->finish();
    $value =~ s/\s+$// if defined $value;
    return $value;
}

sub _build_dbh {
    my $dsn = App::VanTrash::Config->dsn;
    return DBI->connect($dsn, '', '', {AutoCommit => 1});
}

__PACKAGE__->meta->make_immutable;
1;
