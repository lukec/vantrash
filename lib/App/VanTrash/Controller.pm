package App::VanTrash::Controller;
use Moose;
use HTTP::Engine;
use Fatal qw/open/;
use Template;
use App::VanTrash::Model;
use App::VanTrash::Reminder;
use App::VanTrash::Template;
use JSON qw/encode_json decode_json/;
use MIME::Types;
use namespace::clean -except => 'meta';

has 'engine' => (is => 'ro', lazy_build => 1, handles => ['run']);
has 'template' => (is => 'ro', lazy_build => 1);
has 'model' => (is => 'rw', isa => 'App::VanTrash::Model');
has 'mimetypes' => (is => 'ro', lazy_build => 1);
has 'http_module' => (is => 'ro', isa => 'Str', required => 1);
has 'http_args' => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'base_path' => (is => 'ro', isa => 'Str', required => 1);

sub handle_request {
    my $self = shift;
    my $req = shift;

    my $path = $req->path;
    my %func_map = (
        GET => [
            [ qr{^/$}                               => \&ui_html ],
            [ qr{^/([^/]+)\.html$}                  => \&ui_html ],
            [ qr{^/zones$}                          => \&zones_html ],
            [ qr{^/zones\.txt$}                     => \&zones_txt ],
            [ qr{^/zones\.json$}                    => \&zones_json ],
            [ qr{^/zones/([^./]+)$}                 => \&zone_html ],
            [ qr{^/zones/([^/]+)\.txt$}             => \&zone_txt ],
            [ qr{^/zones/([^/]+)\.json$}            => \&zone_json ],
            [ qr{^/zones/([^/]+)/pickupdays$}       => \&zone_days_html ],
            [ qr{^/zones/([^/]+)/pickupdays\.txt$}  => \&zone_days_txt ],
            [ qr{^/zones/([^/]+)/pickupdays\.json$} => \&zone_days_json ],
            [ qr{^/zones/([^/]+)/pickupdays\.ics$}  => \&zone_days_ical ],
            [ qr{^/zones/([^/]+)/nextpickup$} => \&zone_next_pickup_html ],
            [ qr{^/zones/([^/]+)/nextpickup\.txt$} => 
                    \&zone_next_pickup_txt ],
            [ qr{^/zones/([^/]+)/nextpickup\.json$} =>
                    \&zone_next_pickup_json ],
            [ qr{^/zones/([^/]+)/nextdowchange$} => \&zone_next_dow_change_html ],
            [ qr{^/zones/([^/]+)/nextdowchange\.txt$} => 
                    \&zone_next_dow_change_txt ],
            [ qr{^/zones/([^/]+)/nextdowchange\.json$} =>
                    \&zone_next_dow_change_json ],
            [ qr{^/zones/([^/]+)/reminders/([\w\d]+)/confirm$} =>
                    \&confirm_reminder ],
            [ qr{^/zones/([^/]+)/reminders/(.+)/delete$} => 
                    \&delete_reminder_html ],
        ],

        POST => [
            # Website Actions
            [ qr{^/action/tell-friends$} => \&tell_friends ],
        ],
        PUT => [
            [ qr{^/zones/([^/]+)/reminders$} => \&put_reminder ],
        ],
        DELETE => [
            [ qr{^/zones/([^/]+)/reminders/(.+)$} => \&delete_reminder ],
        ],
    );
    
    # Build a model for this request
    $self->model( $self->_build_model );

    my $method = $req->method;
    for my $match (@{ $func_map{$method}}) {
        my ($regex, $todo) = @$match;
        if ($path =~ $regex) {
            if (ref $todo) {
                return $todo->($self, $req, $1, $2, $3, $4);
            }
            else {
                $path = $todo;
            }
        }
    }

    return $self->_static_file($path);
}

sub ui_html {
    my ($self, $req, $tmpl) = @_;
    $tmpl ||= 'index';
    my $params = $req->params;
    return $self->process_template("$tmpl.tt2", $params);
}

sub zones_html {
    my $self = shift;
    my %param = (
        zones => $self->model->zones,
        zone_uri => "/zones",
    );
    return $self->process_template('zones/zones.html', \%param);
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
    return $self->process_template('zones/zone.html', \%param);
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
        has_ical => 1,
    );
    return $self->process_template('zones/days.html', \%param);
}

sub zone_days_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $body = join "\n", map { $_->{string} } @{ $self->model->days($zone) };
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
    my $limit =  $req->param('limit');

    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone/nextpickup",
        days => [$self->model->next_pickup($zone, $limit)],
    );
    return $self->process_template('zones/zone_next_pickup.html', \%param);
}

sub zone_next_pickup_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $limit =  $req->param('limit');

    my $body = join "\n", $self->model->next_pickup($zone, $limit);
    return $self->response('text/plain' => $body);
}

sub zone_next_pickup_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $limit =  $req->param('limit');

    my $body
        = encode_json { next => [ $self->model->next_pickup($zone, $limit) ] };
    return $self->response('application/json' => $body);
}

sub zone_next_dow_change_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;

    my %param = (
        zone => $zone,
        zone_uri => "/zones/$zone/nextdowchange",
        $self->model->next_dow_change($zone),
    );
    return $self->process_template('zones/zone_next_dow_change.html', \%param);
}

sub zone_next_dow_change_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;

    my %days = $self->model->next_dow_change($zone);
    my $body = "Last pickup day before change: " . $days{last}->ymd . "\n"
             . "First pickup day on the new schedule: " . $days{first}->ymd . "\n";
    return $self->response('text/plain' => $body);
}

sub zone_next_dow_change_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;

    my $body = encode_json {$self->model->next_dow_change($zone)};
    return $self->response('application/json' => $body);
}

sub confirm_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $hash = shift;

    my $rem = $self->model->reminders->by_hash($hash);
    unless ($rem) {
        my $resp = $self->process_template('zones/reminders/bad_confirm.html');
        $resp->status(404);
        return $resp;
    }

    $self->model->confirm_reminder($rem);
    my %param = (
        reminder => $rem,
    );
    return $self->process_template('zones/reminders/good_confirm.html', \%param);
}

sub put_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    
    my $args = eval { decode_json $req->raw_body };
    return HTTP::Engine::Response->new( status => 400, body => "Bad JSON" ) if $@;

    my $reminder;
    eval {
        $reminder = App::VanTrash::Reminder->new( %$args, zone => $zone );
    };
    if ($@) {
        return HTTP::Engine::Response->new(status => 400, body => $@);
    }

    if ($self->model->reminders->by_id($reminder->id)) {
        return HTTP::Engine::Response->new(status => 400,
            body => "Reminder already exists! '" . $reminder->id . "'");
    }

    $self->model->add_reminder($reminder);
    my $uri = "/zones/$zone/reminders/" . $reminder->id;
    my $resp = HTTP::Engine::Response->new( status => 201);
    $resp->headers->header( Location => $uri );
    return $resp;
}

sub delete_reminder_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $id   = shift;

    if (my $rem = $self->model->delete_reminder($id)) {
        my $resp = $self->process_template('zones/reminders/good_delete.html', {
            reminder => $rem,
        });
        $resp->status(200);
        return $resp;
    }

    my $resp = $self->process_template('zones/reminders/bad_delete.html');
    $resp->status(404);
    return $resp;
}

sub tell_friends {
    my $self = shift;
    my $req  = shift;

    my $params = { error => 'Not yet implemented, sorry.' };
    my $resp = $self->process_template('tell-a-friend.tt2', $params);
    $resp->status(200);
    return $resp;
}

sub delete_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $id   = shift;

    if ($self->model->delete_reminder($id)) {
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

sub _build_tenjin {
    my $self = shift;
    return Tenjin::Engine->new({
        path => [ $self->base_path . '/template' ],
    });
}

sub _build_template {
    my $self = shift;
    return App::VanTrash::Template->new( base_path => $self->base_path );
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
    if (-f $file) {
        open(my $fh, $file);
        my $resp = HTTP::Engine::Response->new(body => $fh);
        my $ctype = $self->mimetypes->mimeTypeOf($file) || 'text/plain';
        $resp->headers->header('Content-Type' => $ctype);
        return $resp;
    }
    else {
        return HTTP::Engine::Response->new(
            status => 404,
            body => "Sorry, that path doesn't exist!",
        );
    }
}

sub _build_mimetypes { MIME::Types->new }

__PACKAGE__->meta->make_immutable;
1;
