#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use FindBin;
use Fatal qw/mkdir symlink/;
use t::VanTrash;

use_ok 'App::VanTrash::DB';
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

is_deeply $model->reminders->all, [], 'is empty';

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
is scalar(@{ $model->reminders->all }), 1, 'one reminder';

# Re-load the model, see if it persisted
undef $model; $model = App::VanTrash::Model->new( base_path => $tmp_dir );
my $reminders = $model->reminders->all;
is scalar(@$reminders), 1, 'one reminder';
ok !$reminders->[0]->confirmed, 'not confirmed';

# Re-load and confirm the reminder
undef $model; $model = App::VanTrash::Model->new( base_path => $tmp_dir );
$reminders = $model->reminders->all;
$model->reminders->confirm($reminders->[0]);
ok $reminders->[0]->confirmed, 'confirmed';

# Re-load and check the confirmation, then delete it
undef $model; $model = App::VanTrash::Model->new( base_path => $tmp_dir );
$reminders = $model->reminders->all;
ok $reminders->[0]->confirmed, 'confirmed';

$model->delete_reminder($reminders->[0]->id);
$reminders = $model->reminders->all;
is scalar(@$reminders), 0, 'no reminders';

# Re-load and check it's still deleted
undef $model; $model = App::VanTrash::Model->new( base_path => $tmp_dir );
$reminders = $model->reminders->all;
is scalar(@$reminders), 0, 'no reminders';

done_testing();
exit;

