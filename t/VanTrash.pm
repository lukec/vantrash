package t::VanTrash;
use MooseX::Singleton;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;
use Fatal qw/mkdir symlink copy/;
use Test::More;
use File::Slurp;
use mocked 'Net::Twitter';
use mocked 'WWW::Twilio::API';
use mocked 'Business::PayPal::NVP';
use mocked 'Business::PayPal::IPN';

use lib 'lib';
use namespace::clean -except => 'meta';

BEGIN {
    $ENV{VT_EMAIL} = "/tmp/email.$$";

    use_ok 'App::VanTrash::Model';
    use_ok 'App::VanTrash::Log';
    $App::VanTrash::Log::VERBOSE = 1;
}

END { 
    unlink $ENV{VT_EMAIL} if $ENV{VT_EMAIL};
    # Uncomment this for debugging
    # warn qx(cat $ENV{VT_LOG_FILE}) if -e $ENV{VT_LOG_FILE};
}

has 'base_path' => (is => 'ro', lazy_build => 1);

my @http_requests;
{
    no warnings 'redefine';
    *App::VanTrash::Notifier::http_post = sub { push @http_requests, \@_ };
}

sub _build_base_path {
    my $self = shift;

    my $tmp_dir = tempdir( CLEANUP => 0 );
    mkdir "$tmp_dir/data";
    symlink "$FindBin::Bin/../template", "$tmp_dir/template";
    copy "$FindBin::Bin/../data/trash-zone-times.yaml",
        "$tmp_dir/data/trash-zone-times.yaml";
    mkdir "$tmp_dir/etc";
    copy "$FindBin::Bin/../etc/vantrash.yaml.DEFAULT" => "$tmp_dir/etc/vantrash.yaml";

    $ENV{VT_LOG_FILE} = "$tmp_dir/vantrash.log";
    
    # Create the SQL db
    my $db_file = "$tmp_dir/data/vantrash.db";
    my $sql_file = "$FindBin::Bin/../etc/sql/vantrash.sql";
    if ($ENV{VT_LOAD_DATA}) {
        $sql_file = "$FindBin::Bin/../data/vantrash.dump";
    }
    system("sqlite3 $db_file < $sql_file");
    return $tmp_dir;
}

sub app {
    local $ENV{VT_LOAD_DATA} = 1;
    my $test_base = t::VanTrash->base_path;
    App::VanTrash::Config->new( config_file => "$test_base/etc/vantrash.yaml");
    return sub {
        App::VanTrash::Controller->new(
            base_path => $test_base,
            log_file  => "$test_base/vantrash.log",
        )->run(@_);

    };
}

sub model {
    my $self = shift;
    my $test_base = t::VanTrash->base_path;
    return App::VanTrash::Model->new(
        base_path => $test_base,
        log_file  => "$test_base/vantrash.log",
    );
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
