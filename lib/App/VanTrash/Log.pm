package App::VanTrash::Log;
use Moose::Role;
use Fatal qw/open close syswrite/;
use namespace::clean -except => 'meta';

requires 'log_file';

sub log {
    my $self = shift;
    my $msg = localtime() . ": $_[0]\n";
    open(my $fh, '>>', $self->log_file);
    syswrite $fh, $msg;
    close $fh;
}

1;
