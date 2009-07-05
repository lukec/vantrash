package App::VanTrash::Controller;
use Moose;
use HTTP::Engine;
use Fatal qw/open/;
use Template;
use FindBin;
use App::VanTrash::Model;
use JSON qw/encode_json/;
use MIME::Types;

has 'engine' => (is => 'ro', lazy_build => 1, handles => ['run']);
has 'template' => (is => 'ro', lazy_build => 1);
has 'model' => (is => 'ro', isa => 'App::VanTrash::Model', lazy_build => 1);
has 'mimetypes' => (is => 'ro', lazy_build => 1);

sub handle_request {
    my $self = shift;
    my $req = shift;

    my $path = $req->request_uri;
    my @func_map = (
        [ qr{^/$} => 'index.html' ],
        [ qr{^/zones$} => \&zones_html ],
        [ qr{^/zones\.txt$} => \&zones_txt ],
        [ qr{^/zones\.json$} => \&zones_json ],
        [ qr{^/zones/([^./]+)$} => \&zone_html ],
        [ qr{^/zones/([^/]+)\.txt$} => \&zone_txt ],
        [ qr{^/zones/([^/]+)\.json$} => \&zone_json ],
        [ qr{^/zones/([^/]+)/pickupdays$} => \&zone_days_html ],
        [ qr{^/zones/([^/]+)/pickupdays\.txt$} => \&zone_days_txt ],
        [ qr{^/zones/([^/]+)/pickupdays\.json$} => \&zone_days_json ],
        [ qr{^/zones/([^/]+)/nextpickup$} => \&zone_next_pickup_html ],
        [ qr{^/zones/([^/]+)/nextpickup\.txt$} => \&zone_next_pickup_txt ],
        [ qr{^/zones/([^/]+)/nextpickup\.json$} => \&zone_next_pickup_json ],
    );
    for my $match (@func_map) {
        my ($regex, $todo) = @$match;
        if ($path =~ $regex) {
            if (ref $todo) {
                return $todo->($self, $req, $1, $2, $3, $4);
            }
            return $self->_static_file('index.html');
        }
        if ($path =~ m{^/(images/.+|.+\.(css|html))$}) {
            return $self->_static_file($1);
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

sub zone_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = $zone;
    return $self->response('text/plain' => $body);
}

sub zone_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = encode_json { name => $zone };
    return $self->response('application/json' => $body);
}

sub zone_days_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone",
        days => $self->model->days($zone),
    );
    return $self->process_template('zone_days.html', \%param);
}

sub zone_days_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = join "\n", @{ $self->model->days($zone) };
    return $self->response('text/plain' => $body);
}

sub zone_days_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = encode_json $self->model->days($zone);
    return $self->response('application/json' => $body);
}

sub zone_next_pickup_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone",
        day => $self->model->next_pickup($zone),
    );
    return $self->process_template('zone_next_pickup.html', \%param);
}

sub zone_next_pickup_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = $self->model->next_pickup($zone);
    return $self->response('text/plain' => $body);
}

sub zone_next_pickup_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = encode_json { next => $self->model->next_pickup($zone) };
    return $self->response('application/json' => $body);
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
    my $self = shift;
    my $file = "$FindBin::Bin/../static/" . shift;
    open(my $fh, $file);
    my $resp = HTTP::Engine::Response->new(body => $fh);
    my $ctype = $self->mimetypes->mimeTypeOf($file) || 'text/plain';
    $resp->headers->header('Content-Type' => $ctype);
    return $resp;
}

sub _build_mimetypes { MIME::Types->new }

1;
