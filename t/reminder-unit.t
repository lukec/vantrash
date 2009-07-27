#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;
use Fatal qw/mkdir symlink/;

use_ok 'App::VanTrash::Model';
use_ok 'App::VanTrash::Reminder';

my $tmp_dir = tempdir( CLEANUP => 1 );
mkdir "$tmp_dir/data";
symlink "$FindBin::Bin/../template", "$tmp_dir/template";
copy "$FindBin::Bin/../data/trash-zone-times.yaml",
    "$tmp_dir/data/trash-zone-times.yaml";

my $model = App::VanTrash::Model->new( base_path => $tmp_dir );
isa_ok $model, 'App::VanTrash::Model';

my $zones = $model->zones;
isa_ok $zones, 'ARRAY';
my $zone = shift @$zones;

is_deeply $model->all_reminders, [], 'is empty';

my $reminder = App::VanTrash::Reminder->new(
    name => "Test Reminder",
    email => 'test@vantrash.ca',
    zone => $zone,
);
my $rem = $model->add_reminder( $reminder );
isa_ok $rem, 'App::VanTrash::Reminder';
is $rem->name,  'Test Reminder', 'name';
is $rem->email, 'test@vantrash.ca', 'email';
like $rem->id,  qr/^[\w\d]+$/, 'id';

done_testing();
exit;

