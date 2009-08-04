#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use t::VanTrash;
use DateTime;

my $model = t::VanTrash->model;
my $zones = $model->zones;
is_deeply $model->reminders->all, [], 'is empty';

Create_and_send_reminder: {
    my $zone = $zones->[0];
    $model->add_reminder(
        App::VanTrash::Reminder->new(
            name => "Test Reminder",
            email => 'test@vantrash.ca',
            zone => $zone,
            offset => 0,
        )
    );
    my $next_pickup = $model->next_pickup($zone);
    my ($y, $m, $d) = split m/[-\s]/, $next_pickup;
    my $pud = DateTime->new(
        year      => $y, month => $m, day => $d,
        time_zone => 'America/Vancouver',
        hour => 1, # 1 hour ahead of offset => 0
    );

    Email_is_sent: {
        my $reminders = $model->notifier->need_notification( as_of => $pud);
        is scalar(@$reminders), 1, 'found 1 reminder needing notification';
        is $reminders->[0]->name, 'Test Reminder', 'and it had the right name';

        t::VanTrash->clear_email;

        t::VanTrash->set_time($pud);
        $model->notifier->notify($reminders->[0]);
        my $email = t::VanTrash->email_content();
        like $email, qr/garbage day/, 'email matches';
    }

    $pud->set(minute => 10);
    Email_is_not_double_sent: {
        my $reminders = $model->notifier->need_notification( as_of => $pud);
        is scalar(@$reminders), 0, 'no more notifications needed';
    }
}

done_testing();
exit;
