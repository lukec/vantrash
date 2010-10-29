package App::VanTrash::Controller;
use Moose;
use Fatal qw/open/;
use Template;
use App::VanTrash::Model;
use App::VanTrash::Template;
use App::VanTrash::Config;
use App::VanTrash::CallController;
use JSON qw/encode_json decode_json/;
use App::VanTrash::Log;
use Email::Valid;
use Plack::Request;
use Plack::Response;
use namespace::clean -except => 'meta';

has 'log_file'    => (is => 'rw', isa => 'Str', required => 1);
has 'base_path'   => (is => 'ro', isa => 'Str', required => 1);

with 'App::VanTrash::Log';

# State
has 'call_controller' => (is => 'ro', lazy_build => 1);
has 'model'           => (is => 'rw', isa        => 'App::VanTrash::Model');
has 'request'         => (is => 'rw', isa        => 'Plack::Request');
has 'template'        => (is => 'ro', lazy_build => 1);
has 'config'          => (is => 'ro', lazy_build => 1);

our $VERSION = 1.6;

sub run {
    my $self = shift;
    my $env = shift;
    my $req = Plack::Request->new($env);

    $self->request($req);

    my $coord = qr{[+-]?\d+\.\d+};

    my $path = $req->path;
    my %func_map = (
        GET => [
            [ qr{^/$}                               => \&ui_html ],
            [ qr{^/m/?$}                            => \&ui_html ],
            [ qr{^/(.+)\.html$}                     => \&ui_html ],
            [ qr{^/zones$}                          => \&zones_html ],
            [ qr{^/zones\.txt$}                     => \&zones_txt ],
            [ qr{^/zones\.json$}                    => \&zones_json ],
            [ qr{^/zones/($coord),($coord)(.*)?}    => \&zone_at_latlng ],
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
            [ qr{^/zones/([^/]+)/reminders/([\w\d-]+)/confirm$} =>
                    \&confirm_reminder ],
            [ qr{^/zones/([^/]+)/reminders/([\w\d-]+)/delete$} => 
                    \&delete_reminder_html ],
            [ qr{^/reports/(.+)$} => \&show_report ],
            [ qr{^/call(.*)$} => \&handle_call ],
        ],

        POST => [
            # Website Actions
            [ qr{^/action/tell-friends$} => \&tell_friends ],
            [ qr{^/call(.*)$} => \&handle_call ],
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

    return Plack::Response->new(404, [], '');
}

sub handle_call { 
    my $self = shift;
    my $req  = shift;
    my $path = shift;

    return $self->call_controller->handle_request($req, $path);
}

sub is_mobile {
    my ($self, $req) = @_;
    my $headers = $req->headers;
    my $ua_str = $headers->{'user-agent'} || '';
    return $ua_str =~ m{Android|iPhone|BlackBerry}i ? 1 : 0;
}

sub default_page {
    my ($self, $req) = @_;
    return $self->is_mobile($req) ? 'm/index' : 'index';
}

sub ui_html {
    my ($self, $req, $tmpl) = @_;
    $tmpl ||= $self->default_page($req);
    my $params = $req->parameters;
    $params->{zones} = $self->model->zones->all;
    $params->{host_port} = $req->uri->host_port;
    return $self->process_template("$tmpl.tt2", $params)->finalize;
}

sub zones_html {
    my $self = shift;
    $self->log("ZONES HTML");

    my %param = (
        zones => $self->model->zones->all,
        zone_uri => "/zones",
    );
    return $self->process_template('zones/zones.html', \%param)->finalize;
}

sub zones_txt {
    my $self = shift;
    $self->log("ZONES TXT");

    my $body = join("\n", map { $_->{name} } @{ $self->model->zones->all });
    return $self->response('text/plain' => $body);
}

sub zones_json {
    my $self = shift;
    $self->log("ZONES JSON");

    my $body = encode_json $self->model->zones->all;
    return $self->response('application/json' => $body);
}

sub zone_at_latlng {
    my $self = shift;
    my $req  = shift;
    my $lat  = shift;
    my $lng  = shift;
    my $rest = shift || "";

    my $zone = $self->model->kml->find_zone_for_latlng($lat,$lng);
    my $resp = Plack::Response->new;
    if ($zone) {
        $resp->redirect("/zones/$zone$rest", 302);
    }
    else {
        $resp->status(404);
        $resp->body("Sorry, no zone exists at $lat,$lng!");
    }
    return $resp->finalize
}

sub zone_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONE $zone HTML");

    my %param = (
        zone => $self->_load_zone($zone),
    );
    return $self->process_template('zones/zone.html', \%param)->finalize;
}

sub zone_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONE $zone TXT");

    my $zone_hash = $self->_load_zone($zone)->to_hash;
    my $body = '';
    for my $key (keys %$zone_hash) {
        $body .= "$key: $zone_hash->{$key}\n";
    }

    return $self->response('text/plain' => $body);
}

sub zone_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONE $zone JSON");

    my $body = encode_json $self->_load_zone($zone)->to_hash;
    return $self->response('application/json' => $body);
}

sub zone_days_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONEDAYS $zone HTML");

    my %param = (
        zone => $self->_load_zone($zone),
        uri_append => '/pickupdays',
        days => $self->model->days($zone),
        has_ical => 1,
    );
    return $self->process_template('zones/days.html', \%param)->finalize;
}

sub zone_days_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONEDAYS $zone TXT");

    my $body = join "\n", map { $_->{string} } @{ $self->model->days($zone) };
    return $self->response('text/plain' => $body);
}

sub zone_days_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONEDAYS $zone JSON");

    my $body = encode_json $self->model->days($zone);
    return $self->response('application/json' => $body);
}

sub zone_days_ical {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONEDAYS $zone ICAL");

    my $body = $self->model->ical($zone);
    return $self->response('text/calendar' => $body);
}

sub zone_next_pickup_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $limit =  $req->param('limit');
    $self->log("ZONENEXTPICKUP $zone HTML");

    my %param = (
        zone => $self->_load_zone($zone),
        uri_append => '/nextpickup',
        days => [$self->model->next_pickup($zone, $limit)],
    );
    return $self->process_template('zones/zone_next_pickup.html', \%param)->finalize;
}

sub zone_next_pickup_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $limit =  $req->param('limit');
    $self->log("ZONENEXTPICKUP $zone TXT");

    my $body = join "\n", $self->model->next_pickup($zone, $limit);
    return $self->response('text/plain' => $body);
}

sub zone_next_pickup_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $limit =  $req->param('limit');
    $self->log("ZONENEXTPICKUP $zone JSON");

    my $body
        = encode_json { next => [ $self->model->next_pickup($zone, $limit) ] };
    return $self->response('application/json' => $body);
}

sub zone_next_dow_change_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONENEXTDOWCHANGE $zone HTML");

    my %param = (
        zone => $zone,
        uri_append => '/nextdowchange',
        $self->model->next_dow_change($zone, 'return datetime'),
    );
    return $self->process_template('zones/zone_next_dow_change.html', \%param)->finalize;
}

sub zone_next_dow_change_txt {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONENEXTDOWCHANGE $zone TXT");

    my %days = $self->model->next_dow_change($zone, 'return datetime');
    my $body = "Last pickup day before change: " . $days{last}->ymd . "\n"
             . "First pickup day on the new schedule: " . $days{first}->ymd . "\n";
    return $self->response('text/plain' => $body);
}

sub zone_next_dow_change_json {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    $self->log("ZONENEXTDOWCHANGE $zone JSON");

    my $body = encode_json {$self->model->next_dow_change($zone)};
    return $self->response('application/json' => $body);
}

sub confirm_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $hash = shift;
            
    my $is_mobile = $self->is_mobile($req);

    my $rem = $self->model->reminders->by_hash($hash);
    unless ($rem) {
        my $resp = $self->process_template(
            $is_mobile
                ? 'm/reminder_bad_confirm.tt2'
                : 'zones/reminders/bad_confirm.html'
        );
        $resp->status(404);
        $self->log("CONFIRM_FAIL $zone $hash");
        return $resp->finalize;
    }

    unless ($rem->confirmed()) {
        $self->model->confirm_reminder($rem);
        $self->log(join ' ', 'CONFIRM', $zone, $rem->id, $rem->email );
    }
    my %param = (
        reminder => $rem,
    );
    return $self->process_template(
        $is_mobile
            ? 'm/reminder_good_confirm.tt2'
            : 'zones/reminders/good_confirm.html',
        \%param,
    )->finalize;
}

sub _400_bad_request {
    my $self = shift;
    my $msg  = shift;
    
    my $resp = Plack::Response->new(400);
    $resp->content_type('text/plain');
    $resp->body($msg);
    return $resp->finalize;
}

sub put_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    
    my $args = eval { decode_json $req->raw_body };
    return $self->_400_bad_request("Bad JSON") if $@;

    my $addr = Email::Valid->address($args->{email});
    return $self->_400_bad_request("Bad email address") unless $addr;

    my $reminder = $self->model->add_reminder({
            name => $args->{name},
            email => $addr,
            offset => $args->{offset},
            target => $args->{target},
            zone => $zone,
        },
    );
    my $id = $reminder->id;
    $self->log(join ' ', 'ADD', $zone, $reminder->id, $reminder->email );
    my $uri = "/zones/$zone/reminders/" . $id;
    return Plack::Response->new(201, [Location => $uri], '')->finalize;
}

sub _remove_slash {
    (my $url = shift) =~ s{/$}{};
    return $url;
}

sub delete_reminder_html {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $id   = shift;

    my $rem = $self->model->reminders->by_id($id);
    unless ($rem) {
        $self->log("DELETE_FAIL $zone $id");
        my $resp = $self->process_template(
            'zones/reminders/bad_delete.html'
        );
        $resp->status(404);
        return $resp->finalize;
    }

    my $template = 'zones/reminders/confirm_delete.html';
    if ($req->parameters->{confirm}) {
        $template = 'zones/reminders/good_delete.html';
        $self->model->delete_reminder($id);
        $self->log("DELETE $zone $id");
    }

    return $self->process_template($template, {
        reminder => $rem,
    })->finalize;
}

sub tell_friends {
    my $self = shift;
    my $req  = shift;
    my $params = $req->parameters;

    my $tmpl_params = {};
    my $email_str = $params->{friend_emails};
    my $skill_str = $params->{skilltesting} || '';
    my $sender_email = $params->{sender_email};
    if (lc($skill_str) ne 'bc') {
        $tmpl_params->{error} = 'Please answer the Skill testing question correctly.';
        $self->log("TELLAFRIEND_FAIL");
    }
    elsif ($email_str and $sender_email) {
        my @emails = split qr/\s*,?\s+/, $email_str;
        
        for my $email (@emails) {
            $self->model->mailer->send_email(
                to => $email,
                from => $sender_email,
                subject => "Meet the Vancouver Garbage Reminder system",
                template => 'tell-a-friend.html',
                template_args => {
                    friend_email => $sender_email,
                    base => $self->config->base_url,
                    request_uri => $self->request->request_uri,
                },
            );
        }

        $tmpl_params->{success} = "Email sent.  Thanks!";
        $self->log("TELLAFRIEND " . scalar(@emails));
    }
    
    return $self->process_template('tell-a-friend.tt2', $tmpl_params)->finalize;
}

sub delete_reminder {
    my $self = shift;
    my $req  = shift;
    my $zone = shift;
    my $id   = shift;

    if ($self->model->delete_reminder($id)) {
        $self->log("DELETE $zone $id");
        return Plack::Response->new(204, [], '' );
    }

    $self->log("DELETE_FAIL $zone $id");
    return $self->_400_bad_request("Could not delete $id");
}

sub response {
    my $self = shift;
    my $ct   = shift;
    my $body = shift;
    return Plack::Response->new(200, ['Content-Type' => $ct], $body)->finalize;
}

sub _build_template {
    my $self = shift;
    return App::VanTrash::Template->new( base_path => $self->base_path );
}

sub _build_call_controller {
    my $self = shift;
    return App::VanTrash::CallController->new(
        base_path => $self->base_path,
        model => $self->model,
        request => $self->request);
}

sub _build_model {
    my $self = shift;
    return App::VanTrash::Model->new(
        base_path => $self->base_path,
    );
}

sub process_template {
    my $self = shift;
    my $template = shift;
    my $param = shift;
    my $html;
    $param->{version} = $VERSION;
    $param->{base} = $self->config->base_url,
    $param->{request_uri} = $self->request->request_uri;
    $self->template->process($template, $param, \$html) 
        || die $self->template->error;
    my $resp = Plack::Response->new(200);
    $resp->body($html);
    $resp->header('X-UA-Compatible' => 'IE=EmulateIE7');
    return $resp;
}

sub _load_zone {
    my $self = shift;
    my $name = shift;
    return $self->model->zones->by_name( $name );
}

sub _build_config { App::VanTrash::Config->instance };

__PACKAGE__->meta->make_immutable;
1;
