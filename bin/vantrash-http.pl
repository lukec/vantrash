#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::VanTrash::Controller;

App::VanTrash::Controller->new(port => 2009)->run;
exit;
