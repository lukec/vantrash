package App::VanTrash::Scraper;
use Moose;
use Web::Scraper;
use URI;
use YAML qw/DumpFile/;

has 'zones' => (is => 'ro', isa => 'ArrayRef[HashRef]', lazy_build => 1);

sub scrape {
    my $self = shift;

    my %data;
    for my $zone (@{ $self->zones() }) {
        print "Scraping $zone->{name}\n";
        $self->scrape_zone($zone);
        $data{$zone->{name}} = $zone->{dates};
    }

    DumpFile('trash-zone-times.yaml', \%data);
}

sub scrape_zone {
    my $self = shift;
    my $zone = shift;

    my $row_scraper = scraper {
        process 'td.headings', 'months[]' => 'TEXT';
        process 'td:nth-child(2)', 'month1day' => 'TEXT';
        process 'td:nth-child(3) > img', 'month1yard' => '@alt';
        process 'td:nth-child(5)', 'month2day' => 'TEXT';
        process 'td:nth-child(6) > img', 'month1yard' => '@alt';
        process 'td:nth-child(8)', 'month3day' => 'TEXT';
        process 'td:nth-child(9) > img', 'month1yard' => '@alt';
    };

    my $zone_scraper = scraper {
        process 'tr', "rows[]" => $row_scraper;
    };

    my $res = $zone_scraper->scrape( URI->new( $zone->{uri} ) );

    my @dates;
    my @current_months;
    for my $row (@{ $res->{rows} }) {
        if ($row->{months}) {
            @current_months = @{ $row->{months} };
        }
        else {
            for my $i (1 .. 3) {
                my $day = $row->{"month${i}day"};
                next unless $day and $day =~ m/^\d+$/;
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

                push @dates, $date;
            }
        }

    }
    $zone->{dates} = [ sort @dates ];
}


sub _build_zones {
    return [
        {
            name => 'vancouver-north-purple',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/north-purple.htm',
        },
        {
            name => 'vancouver-north-red',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/north-red.htm',
        },
        {
            name => 'vancouver-north-blue',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/north-blue.htm',
        },
        {
            name => 'vancouver-north-green',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/north-green.htm',
        },
        {
            name => 'vancouver-north-yellow',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/north-yellow.htm',
        },
        {
            name => 'vancouver-south-purple',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/south-purple.htm',
        },
        {
            name => 'vancouver-south-red',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/south-red.htm',
        },
        {
            name => 'vancouver-south-blue',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/south-blue.htm',
        },
        {
            name => 'vancouver-south-green',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/south-green.htm',
        },
        {
            name => 'vancouver-south-yellow',
            uri  => 'http://vancouver.ca/ENGSVCS/solidwaste/garbage/south-yellow.htm',
        },
    ];
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

__PACKAGE__->meta->make_immutable;
1;

