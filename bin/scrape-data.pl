#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::VanTrash::Scraper;

my $zone = shift;

my $scraper = App::VanTrash::Scraper->new(
    ($zone ? (zone => $zone) : ()),
    district => 'vancouver',
);
$scraper->scrape;

my $dumpfile = "$FindBin::Bin/../data/vantrash.dump";
print "Dumping database to $dumpfile\n";
system("pg_dump > $dumpfile");
