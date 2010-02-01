package App::VanTrash::Scraper;
use URI;
use Moose;
use FindBin;
use Web::Scraper;
use YAML qw/LoadFile/;
use App::VanTrash::Model;
use namespace::clean -except => 'meta';

has 'region'  => (is => 'ro', isa => 'Str', required => 1);
has 'regions' => (is => 'ro', isa => 'HashRef', lazy_build => 1);
has 'model' => (is => 'ro', isa => 'Object', lazy_build => 1);

sub scrape {
    my $self      = shift;
    my $region_name = $self->region or die "region is mandatory!";

    my $region = $self->regions->{$region_name};
    die "Sorry, '$region_name' is not a valid region" unless $region;
    my $districts = $region->{districts};
    die "Sorry, '$region_name' has no districts defined!" unless @$districts;

    if (! $self->model->regions->by_name($region_name)) {
        print "Adding region to the database!\n";
        my $region = $self->model->regions->add({
                name => $region_name,
                desc => $region->{desc},
                centre => $region->{centre},
                kml_file => "$region_name.kml",
            },
        );
    }

    for my $d (@$districts) {
        print "Adding district $d->{name}\n";
        my $district = $self->model->districts->add({
                region_id => $region->region_id,
                kml_file => "$d->{name}.kml",
                %$d,
            },
        );

        for my $zone (@{ $district->{zones} }) {
            print "Scraping $zone->{name}\n";
            $self->scrape_zone($zone);

            my $zobj = $self->model->zones->add({
                    name => $zone->{name},
                    district_id => $district->district_id,
                    desc => $zone->{desc},
                    colour => $zone->{colour},
                    days => $zone->{days},
                }
            );
        }
    }
}

sub scrape_zone {
    my $self = shift;
    my $zone = shift;
    my $debug = $ENV{VT_DEBUG};

    # XXX: Scraper is hardcoded for Vancouver

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
                my $year = 2009;
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

sub _build_regions {
    my $self = shift;
    my $file = "$FindBin::Bin/../etc/regions.yaml";
    die "Can't find region file: $file!" unless -e $file;
    return LoadFile($file);

}

sub _build_model {
    my $self = shift;
    return App::VanTrash::Model->new(base_path => "$FindBin::Bin/..");
}

__PACKAGE__->meta->make_immutable;
1;

