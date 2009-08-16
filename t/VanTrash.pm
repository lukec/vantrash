package t::VanTrash;
use MooseX::Singleton;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;
use Fatal qw/mkdir symlink/;
use Test::More;
use File::Slurp;
use mocked 'Net::Twitter';
use namespace::clean -except => 'meta';

BEGIN {
    $ENV{VT_EMAIL} = "/tmp/email.$$";

    use_ok 'App::VanTrash::Model';
}

END { unlink $ENV{VT_EMAIL} if $ENV{VT_EMAIL} }

has 'base_path' => (is => 'ro', lazy_build => 1);

my @http_requests;
*App::VanTrash::Notifier::http_post = sub { push @http_requests, \@_ };

sub _build_base_path {
    my $self = shift;

    my $tmp_dir = tempdir( CLEANUP => 1 );
    mkdir "$tmp_dir/data";
    symlink "$FindBin::Bin/../template", "$tmp_dir/template";
    copy "$FindBin::Bin/../data/trash-zone-times.yaml",
        "$tmp_dir/data/trash-zone-times.yaml";
    
    # Create the SQL db
    my $db_file = "$tmp_dir/data/vantrash.db";
    my $sql_file = "$FindBin::Bin/../etc/sql/vantrash.sql";
    if ($ENV{VT_LOAD_DATA}) {
        $sql_file = "$FindBin::Bin/../data/vantrash.dump";
    }
    system("sqlite3 $db_file < $sql_file");
    return $tmp_dir;
}

sub model {
    my $self = shift;
    return App::VanTrash::Model->new( base_path => $self->base_path );
}

sub email_content {
    return eval { scalar read_file($ENV{VT_EMAIL}) } || '';
}

sub clear_email {
    unlink $ENV{VT_EMAIL};
}

sub clear_twitters {
    @Net::Twitter::MESSAGES = ();
}

sub twitters {
    return [ @Net::Twitter::MESSAGES ];
}

sub http_requests {
    return [ @http_requests ];
}

sub set_time {
    my $self = shift;
    my $dt   = shift;

    no warnings 'redefine';
    *App::VanTrash::Notifier::now = sub { $dt->epoch };
}

__PACKAGE__->meta->make_immutable;
1;
