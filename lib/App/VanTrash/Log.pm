package App::VanTrash::Log;
use Moose::Role;
use Fatal qw/open close syswrite/;
use namespace::clean -except => 'meta';

has 'log_file'    => (is => 'rw', isa => 'Str', lazy_build => 1);

sub _build_log_file { '/var/log/vantrash.log' }

sub log {
    my $self = shift;
    my $msg = localtime() . ": $_[0]\n";
    open(my $fh, '>>', $self->log_file);
    syswrite $fh, $msg;
    close $fh;
}

1;
