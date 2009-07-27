package App::VanTrash::Template;
use Moose;
use Template;

has 'base_path' => (is => 'ro', isa => 'Str', required => 1);
has '_template' => (is => 'ro', isa => 'Object', lazy_build => 1,
                    handles => [ qw/process error/ ]);

sub _build__template {
    my $self = shift;
    return Template->new(
        { INCLUDE_PATH => $self->base_path . "/template" },
    );
}

1;
