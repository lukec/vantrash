package App::VanTrash::Controller;
use Moose;
use HTTP::Engine;
use Fatal qw/open/;
use Template;
use App::VanTrash::Model;
use JSON qw/encode_json decode_json/;
use MIME::Types;

has 'engine' => (is => 'ro', lazy_build => 1, handles => ['run']);
has 'template' => (is => 'ro', lazy_build => 1);
has 'model' => (is => 'ro', isa => 'App::VanTrash::Model', lazy_build => 1);
has 'mimetypes' => (is => 'ro', lazy_build => 1);
has 'http_module' => (is => 'ro', isa => 'Str', required => 1);
has 'http_args' => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'base_path' => (is => 'ro', isa => 'Str', required => 1);

sub handle_request {
    my $self = shift;
    my $req = shift;

    my $path = $req->request_uri;
    my %func_map = (
        GET => [
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
            [ qr{^/zones/([^/]+)/pickupdays\.ics$}  => \&zone_days_ical ],
            [ qr{^/zones/([^/]+)/nextpickup$} => \&zone_next_pickup_html ],
            [ qr{^/zones/([^/]+)/nextpickup\.txt$} => \&zone_next_pickup_txt ],
            [ qr{^/zones/([^/]+)/nextpickup\.json$} => \&zone_next_pickup_json ],

            [ qr{^/zones/([^/]+)/reminders$} => \&get_reminders_html ],
            [ qr{^/zones/([^/]+)/reminders\.txt$} => \&get_reminders_txt ],
            [ qr{^/zones/([^/]+)/reminders\.json$} => \&get_reminders_json ],
        ],
        PUT => [
            [ qr{^/zones/([^/]+)/reminders$} => \&put_reminder ],
        ],
        DELETE => [
            [ qr{^/zones/([^/]+)/reminders/(.+)$} => \&delete_reminder ],
        ],
    );
    
    my $method = $req->method;
    for my $match (@{ $func_map{$method}}) {
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
    
    return HTTP::Engine::Response->new(
        status => 404,
        body => "Sorry, that path doesn't exist!",
    );
}

sub zones_html {
    my $self = shift;
    my %param = (
        zones => $self->model->zones,
        zone_uri => "/zones",
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
        zone_uri => "/zones/$zone/pickupdays",
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

sub zone_days_ical {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = $self->model->ical($zone);
    return $self->response('text/calendar' => $body);
}

sub zone_next_pickup_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone/nextpickup",
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

sub get_reminders_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;

    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone/reminders",
        reminders => $self->model->reminders($zone),
    );
    return $self->process_template('reminders.html', \%param);
}

sub get_reminders_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = join "\n", @{ $self->model->reminders($zone) };
    return $self->response('text/plain' => $body);
}

sub get_reminders_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = encode_json { next => $self->model->reminders($zone) };
    return $self->response('application/json' => $body);
}

sub put_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    
    my $rem = eval { decode_json $req->raw_body };
    return HTTP::Engine::Response->new( status => 400, body => "Bad JSON" ) if $@;

    unless ($rem->{id} and $rem->{email}) {
        return HTTP::Engine::Response->new(status => 400,
            body => "Reminder id and email fields are mandatory!");
    }

    if ($self->model->get_reminder($zone, $rem->{id})) {
        return HTTP::Engine::Response->new(status => 400,
            body => "Reminder id already exists! '$rem->{id}'");
    }

    $self->model->add_reminder($zone, $rem);
    return HTTP::Engine::Response->new( status => 201 );
}

sub delete_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $id   = shift;

    if ($self->model->delete_reminder($zone, $id)) {
        return HTTP::Engine::Response->new( status => 204 );
    }

    return HTTP::Engine::Response->new( status => 400 );
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
    my $self = shift;
    return Template->new(
        { INCLUDE_PATH => $self->base_path . "/html" },
    );
}

sub _build_engine {
    my $self = shift;
    return HTTP::Engine->new(
      interface => {
          module => $self->http_module,
          args   => $self->http_args,
          request_handler => sub { $self->handle_request(@_) },
      },
    );
}

sub _build_model {
    my $self = shift;
    return App::VanTrash::Model->new( base_path => $self->base_path );
}

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
    my $file = $self->base_path . "/static/" . shift;
    open(my $fh, $file);
    my $resp = HTTP::Engine::Response->new(body => $fh);
    my $ctype = $self->mimetypes->mimeTypeOf($file) || 'text/plain';
    $resp->headers->header('Content-Type' => $ctype);
    return $resp;
}

sub _build_mimetypes { MIME::Types->new }

1;
