package App::VanTrash::Log;
use MooseX::Singleton;
use FindBin;
use Fatal qw/open close syswrite/;
use namespace::clean -except => 'meta';

has 'log_file' => (is => 'ro', isa => 'Str', lazy_build => 1);

sub log {
    my $self = shift;
    my $msg = localtime() . ": $_[0]\n";
    open(my $fh, '>>', $self->log_file);
    syswrite $fh, $msg;
    close $fh;
}

sub _build_log_file {
    my $self = shift;
    if ($< >= 1000) {
        return "$FindBin::Bin/../vantrash.log";
    }
    return "/var/log/vantrash.log";
}

__PACKAGE__->meta->make_immutable;
1;
