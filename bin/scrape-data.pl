#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::VanTrash::Scraper;

my $scraper = App::VanTrash::Scraper->new();
$scraper->scrape;
