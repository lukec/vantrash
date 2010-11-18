package App::VanTrash::Email;
use Moose;
use Email::Send;
use Email::MIME;
use Email::MIME::Creator;
use Email::Send::Gmail;
use Email::Send::IO;
use Net::SMTP::SSL;
use YAML;
use App::VanTrash::Template;
use App::VanTrash::Config;
use namespace::clean -except => 'meta';

has 'base_path' => (is => 'ro', isa => 'Str',    required   => 1);
has 'mailer'    => (is => 'ro', isa => 'Object', lazy_build => 1);
has 'template' => (is => 'ro', lazy_build => 1);

sub send_email {
    my $self = shift;
    my %args = @_;

    my $body;
    my $template = "email/$args{template}";
    $args{template_args}{base} = App::VanTrash::Config->instance->base_url();
    $self->template->process($template, $args{template_args}, \$body) 
        || die $self->template->error;

    my %headers = (
        From => $args{from} || '"VanTrash" <noreply@vantrash.ca>',
        To => $args{to},
        Subject => $args{subject},
    );
    my $email = Email::MIME->create(
        attributes => {
            content_type => 'text/plain',
            disposition => 'inline',
            charset => 'utf8',
        },
        body => $body,
    );
    $email->header_set( $_ => $headers{$_}) for keys %headers;

    $self->mailer->send($email);
}

sub _build_mailer {
    my $self = shift;

    if ($ENV{VT_EMAIL}) {
        @Email::Send::IO::IO = ($ENV{VT_EMAIL});
        return Email::Send->new({
            mailer => 'IO',
        });
    }

    my $config_file = $ENV{VANTRASH_DEV_ENV}
        ? './etc/vantrash_mail.yaml'
        : '/etc/vantrash_mail.yaml';
    die "File doesn't exist: $config_file" unless -f $config_file;
    my $config = YAML::LoadFile($config_file);
    my $mailer = Email::Send->new({
        mailer => 'Gmail',
        mailer_args => [
            username => delete $config->{username},
            password => delete $config->{password},
        ]
    });
    return $mailer;
}

sub _build_template {
    my $self = shift;
    return App::VanTrash::Template->new( base_path => $self->base_path );
}

__PACKAGE__->meta->make_immutable;
1;
