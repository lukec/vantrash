package App::VanTrash::Controller;
use Moose;
use HTTP::Engine;
use Fatal qw/open/;
use Template;
use FindBin;
use App::VanTrash::Model;
use JSON qw/encode_json/;

has 'engine' => (is => 'ro', lazy_build => 1, handles => ['run']);
has 'template' => (is => 'ro', lazy_build => 1);
has 'model' => (is => 'ro', isa => 'App::VanTrash::Model', lazy_build => 1);

sub handle_request {
    my $self = shift;
    my $req = shift;

    my $path = $req->request_uri;
    my @func_map = (
        [ qr{^/$} => 'index.html' ],
        [ qr{^/zones$} => \&zones_html ],
        [ qr{^/zones\.txt$} => \&zones_txt ],
        [ qr{^/zones\.json$} => \&zones_json ],
        [ qr{^/zones/([^/]+)$} => \&zone_html ],
        [ qr{^/zones/([^/]+)/pickupdays$} => \&zone_days ],
    );
    for my $match (@func_map) {
        my ($regex, $todo) = @$match;
        if ($path =~ $regex) {
            if (ref $todo) {
                return $todo->($self, $req, $1, $2, $3, $4);
            }
            return _static_file('index.html');
        }
    }
    return HTTP::Engine::Response->new(body => "Unknown - $path");
}

sub zones_html {
    my $self = shift;
    my %param = (
        zones => $self->model->zones,
    );
    return $self->process_template('zones.html', \%param);
}

sub zones_txt {
    my $self = shift;
    my $body = join("\n", @{ $self->model->zones });
    my $res = HTTP::Engine::Response->new(body => $body);
    return $self->response('text/plain' => $body);
}

sub zones_json {
    my $self = shift;
    my $body = encode_json $self->model->zones;
    return $self->response('application/json' => $body);
}

sub zone_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;

    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone",
    );
    return $self->process_template('zone.html', \%param);
}

sub zone_days {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my %param = (
        zone => $zone,
        days => $self->model->days($zone),
    );
    return $self->process_template('zone_days.html', \%param);
}

sub response {
    my $self = shift;
    my $ct   = shift;
    my $body = shift;
    my $res = HTTP::Engine::Response->new;
    $res->headers->header('Content-Type' => $ct);
    $res->body($body);
    return $res;
}

sub _build_template {
    return Template->new(
        { INCLUDE_PATH => "$FindBin::Bin/../html" },
    );
}

sub _build_engine {
    my $self = shift;
    return HTTP::Engine->new(
      interface => {
          module => 'ServerSimple',
          args   => {
              host => 'localhost',
              port =>  2009,
              net_server => 'Net::Server::PreForkSimple',
              net_server_configure => {
                  max_servers  => 5,
                  max_requests => 100,
              },
          },
          request_handler => sub { $self->handle_request(@_) },
      },
    );
}

sub _build_model { App::VanTrash::Model->new }

sub process_template {
    my $self = shift;
    my $template = shift;
    my $param = shift;
    my $html;
    $self->template->process($template, $param, \$html) 
        || die $self->template->error;
    return HTTP::Engine::Response->new(body => $html);
}

sub _static_file {
    my $file = "$FindBin::Bin/../html/" . shift;
    open(my $fh, $file);
    return HTTP::Engine::Response->new(body => $fh);
}

1;
