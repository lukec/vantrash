#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Copy qw/copy/;
use FindBin;
use IO::All;
use t::VanTrash;

use_ok 'App::VanTrash::Email';

my $email = App::VanTrash::Email->new( base_path => "$FindBin::Bin/.." );
isa_ok $email, 'App::VanTrash::Email';

$email->send_email(
    to => 'test@vantrash.ca',
    subject => "You've won one million dollars!",
    template => 'test',
    template_args => { foo => 'bar' },
);

open(my $fh, $ENV{VT_EMAIL});
local $/ = undef;
my $contents = <$fh>;
like $contents, qr/\QTo: test/, 'to';
like $contents, qr/\QFrom: "VanTrash" <noreply/, 'from';
like $contents, qr/\QSubject: You've won\E/, 'subject';
like $contents, qr/foo is bar/, 'template works';

done_testing();
exit;

