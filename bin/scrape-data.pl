#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::VanTrash::Scraper;

my $zone = shift;

my $scraper = App::VanTrash::Scraper->new(
    ($zone ? (zone => $zone) : ()),
    area => 'vancouver',
);
$scraper->scrape;

my $dumpfile = "$FindBin::Bin/../data/vantrash.dump";
print "Dumping database to $dumpfile\n";
system("echo '.dump' | sqlite3 data/vantrash.db > $dumpfile");
