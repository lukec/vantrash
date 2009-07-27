package App::VanTrash::Template;
use Moose;
use Template;

has 'base_path' => (is => 'ro', isa => 'Str', required => 1);
has '_template' => (is => 'ro', isa => 'Object', lazy_build => 1,
                    handles => [ qw/process error/ ]);

sub _build__template {
    my $self = shift;
    my $templ_path = $self->base_path . '/template';
    unless (-d $templ_path) {
        die "No such template path! $templ_path";
    }
    return Template->new(
        { INCLUDE_PATH => $templ_path },
    );
}

1;
