#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;

use_ok 'App::VanTrash::Model';
use_ok 'App::VanTrash::Reminder';

my $tmp_dir = tempdir( CLEANUP => 1 );
copy "$FindBin::Bin/../data/trash-zone-times.yaml", $tmp_dir;

my $model = App::VanTrash::Model->new( data_path => $tmp_dir );
isa_ok $model, 'App::VanTrash::Model';

my $zones = $model->zones;
isa_ok $zones, 'ARRAY';
my $zone = shift @$zones;

is_deeply $model->reminders($zone), [], 'is empty';

my $reminder = App::VanTrash::Reminder->new(
    name => "Test Reminder",
    email => 'test@vantrash.ca',
    zone => $zone,
);
my $rem = $model->add_reminder( $reminder );
isa_ok $rem, 'App::VanTrash::Reminder';
is $rem->name,  'Test Reminder', 'name';
is $rem->email, 'test@vantrash.ca', 'email';
is $rem->id,    'test@vantrash.ca-test_reminder', 'id';

done_testing();
exit;

