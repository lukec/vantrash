package Socialtext::WikiFixture::VanTrash;
use Moose::Role;
use App::VanTrash::Model;
use IPC::Run qw/start finish/;
use Test::More;
use File::Path qw/mkpath rmtree/;
use IO::All;

has 'model' => (is => 'ro', isa => 'App::VanTrash::Model', lazy_build => 1);
has 'http_server' => (is => 'rw', isa => 'HashRef');
has 'email_file' => (is => 'ro', isa => 'Str', lazy_build => 1);

after 'init' => sub {
    my $self = shift;
    $self->start_up_http_server;
    $self->clear_reminders;
};

after 'stop' => sub {
    my $self = shift;
    $self->stop_http_server;
};

sub stop_http_server {
    my $self = shift;
    my $server = $self->http_server || return;

    my $h = $server->{handle};
    $h->pump_nb;
    $h->kill_kill();
    if (my $msg = ${ $server->{output}}) {
        warn $msg;
    }
}

sub start_up_http_server {
    my $self = shift;

    system("killall perl");
    my $out = '';
    my $base_dir = base_path();
    $ENV{VT_EMAIL} = $self->email_file;
    my @command = ($^X, "$base_dir/bin/vantrash-http.pl");
    my $handle = start(\@command, \*STDIN, \$out, \$out);
    $self->http_server( {
            handle => $handle,
            output => \$out,
        }
    );
    die "Failed to run @command" unless $handle;
    sleep 1;
    pump $handle;
    unless ($out =~ m/Starting up HTTP server on port (\d+)/) {
        die "Couldn't find HTTP port:\n$out\n";
    }
    $out = "";
    $self->{base_url} = "http://localhost:$1";
    diag "Setting base_url to $self->{base_url}";
}

sub clear_reminders {
    my $self = shift;
    my $model = $self->model;
    my $zones = $model->zones;
    for my $zone (@$zones) {
        my $reminders = $model->reminders($zone);
        for my $r (@$reminders) {
            $model->delete_reminder($zone, $r);
        }
    }
}

sub reminder_count_is {
    my $self = shift;
    my $count = shift;

    my $all_reminders = $self->model->all_reminders;
    is scalar(@$all_reminders), $count, 'reminder count';
}

sub clear_email {
    my $self = shift;
    unlink $self->email_file;
}

sub email_like {
    my $self = shift;
    my $regex = shift;

    like $self->email_contents, $regex, 'email matches';
}

sub email_contents {
    my $self = shift;
    return '' unless -e $self->email_file;
    return scalar(io($self->email_file)->slurp);
}

sub get_confirm_url {
    my $self = shift;
    my $var  = shift;

    my $email = $self->email_contents;
    my $url;
    if ($email =~ m#\bhttp://vantrash\.ca([\S+]+)\b#) {
        $url = $1;
    }
    die "Could not find a confirmation url in this mess\n$email\n" unless $url;

    $self->clear_email();
    $self->get($url);
}

sub base_path {
    my $file = $INC{'Socialtext/WikiFixture/VanTrash.pm'};
    (my $dir = $file) =~ s#(.+)/.+#$1#;
    return "$dir/../../..";
}

sub _build_model {
    return App::VanTrash::Model->new( base_path => base_path() );
}

sub _build_email_file {
    my $file = "/tmp/email.$$";
    return $file;
}

1;
