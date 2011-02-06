package App::VanTrash::Scraper;
use URI;
use Moose;
use FindBin;
use Web::Scraper;
use YAML qw/LoadFile/;
use App::VanTrash::Model;
use namespace::clean -except => 'meta';

has 'zone'  => (is => 'ro', isa => 'Str');
has 'area'  => (is => 'ro', isa => 'Str', required => 1);
has 'areas' => (is => 'ro', isa => 'HashRef', lazy_build => 1);
has 'model' => (is => 'ro', isa => 'Object', lazy_build => 1);

sub scrape {
    my $self      = shift;
    my $area_name = $self->area or die "area is mandatory!";
    my $only_zone = $self->zone;

    my $area = $self->areas->{$area_name};
    die "Sorry, '$area_name' is not a valid area" unless $area;
    my $zones = $area->{zones};
    die "Sorry, '$area_name' has no zones defined!" unless @$zones;

    if (! $self->model->areas->by_name($area_name)) {
        $self->model->areas->add({
                name => $area_name,
                desc => $area->{desc},
                centre => $area->{centre},
            },
        );
    }

    for my $zone (@$zones) {
        next if $only_zone and $zone->{name} ne $only_zone;
        print "Scraping $zone->{name}\n";
        $self->scrape_zone($zone);

        my $zobj = $self->model->zones->add({
            name => $zone->{name},
            desc => $zone->{desc},
            area => $area_name,
            colour => $zone->{colour},
            days => $zone->{days},
            }
        );
    }
}

sub scrape_zone {
    my $self = shift;
    my $zone = shift;
    my $debug = $ENV{VT_DEBUG};

    my $row_scraper = scraper {
        process 'td.headings', 'months[]' => 'TEXT';
        process 'td:nth-child(2)', 'month1day' => 'TEXT';
        process 'td:nth-child(3) > img', 'month1yard' => '@alt';
        process 'td:nth-child(5)', 'month2day' => 'TEXT';
        process 'td:nth-child(6) > img', 'month2yard' => '@alt';
        process 'td:nth-child(8)', 'month3day' => 'TEXT';
        process 'td:nth-child(9) > img', 'month3yard' => '@alt';
    };

    my $zone_scraper = scraper {
        process 'tr', "rows[]" => $row_scraper;
    };

    my $res = $zone_scraper->scrape( URI->new( $zone->{url} ) );

    my @days;
    my @current_months;
    for my $row (@{ $res->{rows} }) {
        if ($row->{months}) {
            @current_months = @{ $row->{months} };
        }
        else {
            for my $i (1 .. 3) {
                my $day = $row->{"month${i}day"};
                next unless $day;
                next if $day =~ m/^\s*$/ or $day =~ m/Set out by 7/;
                unless ($day and $day =~ m/^\s*(\d+)\s*$/) {
                    warn "Couldn't recognize: '$day'\n";
                    next;
                }
                $day = $1;
                my $year = 2010;
                my $month = $current_months[$i - 1];
                if ($month =~ s/^(\w+) (\d+)/$1/) {
                    $year = $2;
                }

                my $month_num = _month_to_num($month);
                my $date = sprintf '%4d-%02d-%02d', $year,$month_num,$day;

                if ($row->{"month${i}yard"}) {
                    $date .= ' Y';
                }

                push @days, $date;
            }
        }

    }

    $zone->{days} = [ sort @days ];

    # In Vancouver, the colour always comes at the end of the zone name..
    ($zone->{colour} = $zone->{name}) =~ s/.+-//;

}


sub _month_to_num {
    my $name = shift;
    $name =~ s/\s*(\S+)\s*/$1/;
    return {
        january => 1,
        february => 2,
        march => 3,
        april => 4,
        may => 5,
        june => 6,
        july => 7,
        august => 8,
        september => 9,
        october => 10,
        november => 11,
        december => 12,
    }->{lc $name} || die "No month for $name";
}

sub _build_areas {
    my $self = shift;
    my $file = "$FindBin::Bin/../etc/areas.yaml";
    die "Can't find area file: $file!" unless -e $file;
    return LoadFile($file);

}

sub _build_model {
    my $self = shift;
    return App::VanTrash::Model->new(base_path => "$FindBin::Bin/..");
}

__PACKAGE__->meta->make_immutable;
1;

