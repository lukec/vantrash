package App::VanTrash::CallController;
use Moose;
use Email::MIME;
use App::VanTrash::Email;
use namespace::clean -except => 'meta';

has 'request' => (is => 'rw', isa => 'HTTP::Engine::Request', required => 1);
has 'model' => (is => 'rw', isa => 'App::VanTrash::Model', required => 1);
has 'base_path' => (is => 'ro', isa => 'Str', required => 1);
# TODO - logger should be a role
has 'logger' =>
    (default => sub { App::VanTrash::Log->new }, handles => ['log']);


our $VERSION = 1.6;

sub handle_request {
    my $self = shift;
    my $req = shift;
    my $path = shift;

    my @func_map = (
        [ qr{^/start$}       => \&start ],
        [ qr{^/show/main$}   => \&show_main_menu ],
        [ qr{^/gather/main$} => \&process_main_menu ],

        [ qr{^/show/lookup_menu$}              => \&show_lookup_menu ],
        [ qr{^/gather/lookup$}                 => \&process_region ],
        [ qr{^/show/zones_menu/(north|south)$} => \&show_zones_menu ],
        [ qr{^/gather/lookup/(north|south)$}   => \&lookup_zone ],

        [ qr{^/show/message_prompt$} => \&show_message_prompt ],
        [ qr{^/receive/message$}     => \&receive_message ],
        [ qr{^/goodbye$}             => \&goodbye ],
    );

    my $response = '';
    for my $match (@func_map) {
        my ($regex, $callback) = @$match;
        if ($path =~ $regex) {
            $response = $callback->($self, $req, $1, $2, $3, $4);
            last;
        }
    }

    my $resp = HTTP::Engine::Response->new( status => 200 );
    $resp->headers->header('Content-Type' => 'text/xml');
    $resp->headers->header('Cache-Control' => 'no-cache, no-store, must-revalidate');
    $response ||= "<Say voice=\"woman\">I'm sorry.  Lets start at the beginning.</Say>"
            . "<Redirect>/call/start</Redirect>";

    my $body = <<EOT;
<?xml version="1.0" encoding="UTF-8"?>
<Response>
$response
</Response>
EOT
    $resp->body($body);

    return $resp;
}

sub start { 
    return <<EOT;
        <Say voice="woman">
            Hello, you have reached Van Trash.  
        </Say>
        <Redirect>/call/show/main</Redirect>
EOT
}

sub show_main_menu {
    return <<EOT;
    <Gather action="/call/gather/main" method="POST" numDigits="1" timeout="7">
        <Say voice="woman">
            To look up the garbage day, press 1.
            To leave a message for VanTrash, press 2.
        </Say>
    </Gather>
    <Say voice="woman">Lets try that again.</Say>
    <Redirect>/call/show/main</Redirect>
EOT
}

sub process_main_menu {
    my ($self, $req, @args) = @_;

    my $num = $req->params->{Digits};
    if ($num and $num =~ m/^[12]$/) {
        if ($num == 1) {
            return '<Redirect>/call/show/lookup_menu</Redirect>';
        }
        elsif ($num == 2) {
            return '<Redirect>/call/show/message_prompt</Redirect>';
        }
    }
    return "<Say voice=\"woman\">Please choose one or two.</Say>"
        . "<Redirect>/call/show/main</Redirect>";
}

sub show_lookup_menu { 
    return <<EOT;
<Gather action="/call/gather/lookup" method="POST" numDigits="1" timeout="7">
    <Say voice="woman">
        Which zone would you like to know the schedule for?
        For Vancouver North zones, press 1.
        For Vancouver South zones, press 2.
    </Say>
    <Pause length="2"/>
    <Say voice="woman">
      If you are not sure which zone you live in, go to our website at: van trash dot C A.
    </Say>
</Gather>
<Say voice="woman">Lets try that again.</Say>
<Redirect>/call/show/lookup_menu</Redirect>
EOT
}

sub show_message_prompt {
    return <<EOT;
   <Say voice="woman">
     Please leave your message for VanTrash. 
     Press pound or hang up when you are done.
   </Say>
   <Record action="/call/goodbye" method="POST" finishOnKey="#" maxLength="120"
    transcribe="true" transcribeCallback="/call/receive/message" />
   <Say voice="woman">Thank you.</Say>
   <Say voice="man">Thank you.</Say>
   <Hangup/>
EOT
}
sub process_region {
    my ($self, $req, @args) = @_;

    my $num = $req->params->{Digits};
    if ($num and $num =~ m/^[12]$/) {
        my $type = $num == 1 ? 'north' : 'south';
        return "<Redirect>/call/show/zones_menu/$type</Redirect>";
    }
    return "<Say voice=\"woman\">Please choose one or two.</Say>"
        . "<Redirect>/call/show/main</Redirect>";
}

sub show_zones_menu {
    my ($self, $req, $type) = @_;
    return <<EOT;
<Gather action="/call/gather/lookup/$type" method="POST" numDigits="1" timeout="7">
    <Say voice="woman">
        For the red $type zone, press 1.
        For blue $type, press 2.
        For green $type, press 3.
        For purple $type, press 4.
        And for yellow $type, press 5.
    </Say>
</Gather>
<Say voice="woman">Lets try that again.</Say>
<Redirect>/call/show/zones_menu/$type</Redirect>
EOT
}

sub lookup_zone {
    my ($self, $req, @args) = @_;
    my $type   = $args[0];

    my $num = $req->params->{Digits};
    if ($num and $num =~ m/^[12345]$/) {
        my @zones = (undef, qw/red blue green purple yellow/);
        my $zone_name = "vancouver-$type-$zones[$num]";
        my $d  = $self->model->next_pickup($zone_name, 1, 0, 'obj please');
        my $dt = $d->datetime;
        my $nice_date = $dt->day_name . ', ' .
            $dt->month_name . ' ' . $dt->day;
        my $extra = "No yard trimmings will be picked up.";
        if ($d->flags =~ m/Y/) {
            $extra = "Yard trimmings and food compost will be picked up.";
        }
        return <<EOT;
    <Say voice="woman">
      The next pickup day for Vancouver $type $zones[$num] is: $nice_date. $extra
    </Say>
    <Pause length="2"/>
    <Say voice="woman">Have a nice day.</Say>
    <Hangup/>
EOT
    }
    return "<Say voice=\"woman\">Please choose one of the zones.</Say>"
        . "<Redirect>/call/show/zones_menu/$type</Redirect>";
}

sub receive_message {
    my ($self, $req, @args) = @_;
    my $params = $req->params;

    my $body = "A new voicemail is available at: $params->{RecordingUrl}\n\n";
    if ($params->{TranscriptionStatus} eq 'completed') {
        $body .= "Transcription: $params->{TranscriptionText}\n";
    }
    my %headers = (
        From    => '"VanTrash" <noreply@vantrash.ca>',
        To      => 'info@vantrash.ca',
        Subject => "New VanTrash voicemail message",
    );
    my $email = Email::MIME->create(
        attributes => {
            content_type => 'text/plain',
            disposition  => 'inline',
            charset      => 'utf8',
        },
        body => $body,
    );
    $email->header_set($_ => $headers{$_}) for keys %headers;

    my $emailer = App::VanTrash::Email->new(
        base_path => $self->base_path,
    );
    $emailer->mailer->send($email);
}

sub goodbye { "<Say voice=\"woman\">Goodbye.</Say><Hangup/>" }

__PACKAGE__->meta->make_immutable;
1;
