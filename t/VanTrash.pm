package t::VanTrash;
use MooseX::Singleton;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;
use Fatal qw/mkdir symlink/;
use Test::More;
use IO::All;
use namespace::clean -except => 'meta';

BEGIN {
    $ENV{VT_EMAIL} = "/tmp/email.$$";

    use_ok 'App::VanTrash::DB';
    use_ok 'App::VanTrash::Model';
    use_ok 'App::VanTrash::Reminder';
}

END { unlink $ENV{VT_EMAIL} if $ENV{VT_EMAIL} }

has 'base_path' => (is => 'ro', lazy_build => 1);

sub _build_base_path {
    my $self = shift;

    my $tmp_dir = tempdir( CLEANUP => 1 );
    mkdir "$tmp_dir/data";
    symlink "$FindBin::Bin/../template", "$tmp_dir/template";
    copy "$FindBin::Bin/../data/trash-zone-times.yaml",
        "$tmp_dir/data/trash-zone-times.yaml";
    return $tmp_dir;
}

sub model {
    my $self = shift;
    return App::VanTrash::Model->new( base_path => $self->base_path );
}

sub email_content {
    return eval { scalar(io($ENV{VT_EMAIL})->slurp) } || '';
}

sub clear_email {
    unlink $ENV{VT_EMAIL};
}

__PACKAGE__->meta->make_immutable;
1;
