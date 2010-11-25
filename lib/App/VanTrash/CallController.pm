package App::VanTrash::CallController;
use Moose;
use Email::MIME;
use Plack::Response;
use App::VanTrash::Email;
use namespace::clean -except => 'meta';

with 'App::VanTrash::ControllerBase';

use constant Version => 1.6;

sub run {
    my $self = shift;
    my $req = $self->request;
    my $path = $req->path;

    my @func_map = (
        [ qr{^/start$}       => \&start ],
        [ qr{^/show/main$}   => \&show_main_menu ],
        [ qr{^/gather/main$} => \&process_main_menu ],

        [ qr{^/show/lookup_menu$}              => \&show_lookup_menu ],
        [ qr{^/gather/lookup$}                 => \&process_region ],
        [ qr{^/show/zones_menu/(north|south)$} => \&show_zones_menu ],
        [ qr{^/gather/lookup/(north|south)$}   => \&lookup_zone ],

        [ qr{^/notify/([\w-]+)$}     => \&voice_notify ],
        [ qr{^/show/message_prompt$} => \&show_message_prompt ],
        [ qr{^/receive/message$}     => \&receive_message ],
        [ qr{^/goodbye$}             => \&goodbye ],
        [ qr{^/new-user-welcome/(\w+)$}    => \&new_user_welcome ],
    );

    my $response = '';
    for my $match (@func_map) {
        my ($regex, $callback) = @$match;
        if ($path =~ $regex) {
            $response = $callback->($self, $req, $1, $2, $3, $4);
            last;
        }
    }

    my $resp = Plack::Response->new(200);
    $resp->header('Content-Type' => 'text/xml');
    $resp->header('Cache-Control' => 'no-cache, no-store, must-revalidate');
    $response ||= "<Say voice=\"woman\">I'm sorry.  Lets start at the beginning.</Say>"
            . "<Redirect>/call/start</Redirect>";

    my $body = <<EOT;
<?xml version="1.0" encoding="UTF-8"?>
<Response>
$response
</Response>
EOT
    $resp->body($body);

    return $resp->finalize;
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
            To leave a message telling us how much you love Van Trash, press 2.
        </Say>
    </Gather>
    <Say voice="woman">Lets try that again.</Say>
    <Redirect>/call/show/main</Redirect>
EOT
}

sub process_main_menu {
    my ($self, $req, @args) = @_;

    my $num = $req->parameters->{Digits};
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

    my $num = $req->parameters->{Digits};
    if ($num and $num =~ m/^[12]$/) {
        my $type = $num == 1 ? 'north' : 'south';
        return "<Redirect>/call/show/zones_menu/$type</Redirect>";
    }
    return "<Say voice=\"woman\">Please choose one or two.</Say>"
        . "<Redirect>/call/show/main</Redirect>";
}

sub voice_notify {
    my ($self, $req, $zone_name) = @_;
    my $zone = $self->model->zones->by_name($zone_name) or return;

    my $pickup = $self->model->next_pickup($zone_name, 1, undef, 'obj please');
    my $day_name = $pickup->datetime->day_name;
    my $extra = 'No commpost pickup this week.';
    if ($pickup->flags =~ m/y/i) {
        $extra = "Food scraps and yard trimmings will be picked up too.";
    }

    my $zone_desc = $zone->desc;
    return <<EOT;
<Pause length="1"/>
<Say voice="woman">Hello, this is Van Trash. I hope you are feeling dirty, because garbage day is almost here!  Your garbage will be removed on $day_name.  $extra</Say>
<Hangup/>
EOT
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

    my $num = $req->parameters->{Digits};
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
    my $params = $req->parameters;

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

sub new_user_welcome { 
    my $self = shift;
    my $req  = shift;
    my $type = shift;

    my %action = ( sms => 'text', voice => 'call' );

    return "<Say voice=\"woman\">Hello, this is Van Trash.  We have created your new reminder and we will $action{$type} you each week.  If you need to look up the garbage day from your phone, call me back and I can help you.  My number is 778-785-1357, and you can also find it on our web site.  We appreciate your support, and hope that you find this service useful. If you have any problems or suggestions phone me and leave a message, tweet us, or send us an email at help at van trash dot C A.</Say><Pause length=\"1\"/><Say voice=\"woman\">Goodbye.</Say><Hangup/>"
}

__PACKAGE__->meta->make_immutable;
1;
