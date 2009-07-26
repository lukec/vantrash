package Socialtext::WikiFixture::VanTrash;
use Moose::Role;
use App::VanTrash::Model;
use IPC::Run qw/start finish/;
use Test::More;
use File::Path qw/mkpath rmtree/;

has 'model' => (is => 'ro', isa => 'App::VanTrash::Model', lazy_build => 1);
has 'http_server' => (is => 'rw', isa => 'HashRef');

after 'init' => sub {
    my $self = shift;
    $self->start_up_http_server;
};

after 'stop' => sub {
    my $self = shift;
    $self->stop_http_server;
};

sub stop_http_server {
    my $self = shift;
    my $server = $self->http_server || return;
    $server->{handle}->kill_kill();
}

sub start_up_http_server {
    my $self = shift;

    my $out = '';
    
    my $file = $INC{'Socialtext/WikiFixture/VanTrash.pm'};
    (my $dir = $file) =~ s#(.+)/.+#$1#;
    my $base_dir = "$dir/../../..";
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
    $self->{base_url} = "http://localhost:$1";
    diag "Setting base_url to $self->{base_url}";
}

sub _build_model {
    my $base_path = "$FindBin::Bin/../t/root";
    if (-d $base_path) {
        rmtree $base_path;
    }
    mkpath $base_path;
    return App::VanTrash::Model->new( base_path => $base_path );
}

1;
