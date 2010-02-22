#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use t::VanTrash;
use DateTime;

$ENV{VT_LOAD_DATA} = 1;
t::VanTrash->set_time( DateTime->new(year => 2009, month => 6, day => 1) );

Create_and_send_reminder: {
    my $model = t::VanTrash->model;
    my $zones = $model->zones->all('objects');
    is_deeply $model->reminders->all, [], 'is empty';

    my $zone = $zones->[0];
    my $robj = $model->add_reminder({
        name => "Test Reminder",
        email => 'test@vantrash.ca',
        zone => $zone->name,
        offset => 0,
    });
    my $next_pickup = $model->next_pickup($zone->name);
    my ($y, $m, $d) = split m/[-\s]/, $next_pickup;
    my $pud = DateTime->new(
        year      => $y, month => $m, day => $d,
        time_zone => 'America/Vancouver',
        hour => 1, # 1 hour ahead of offset => 0
    );

    Not_sent_before_confirmation: {
        my $reminders = $model->notifier->need_notification( as_of => $pud);
        is scalar(@$reminders), 0, 'no more notifications needed';
        $reminders = $model->reminders->all('objects');
        is scalar(@$reminders), 1, '1 reminder exists';
        $model->confirm_reminder($reminders->[0]);
    }

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

    Unknown_target: {
        # Set up reminder to be able to do another update
        $robj->target('unknown:monkey');
        $robj->last_notified(0);
        $robj->update;

        my $reminders = $model->notifier->need_notification( as_of => $pud);
        is scalar(@$reminders), 1, 'reminder needs notification again';
        eval { $model->notifier->notify($reminders->[0]) };
        like $@, qr/No such target/, 'error was raised';
    }

    Twitter: {
        # Set up reminder to be able to do another update
        $robj->target('twitter:lukec');
        $robj->last_notified(0);
        $robj->update;

        my $reminders = $model->notifier->need_notification( as_of => $pud);
        is scalar(@$reminders), 1, 'reminder needs notification again';
        $model->notifier->notify($reminders->[0]);
        my $tweets = t::VanTrash->twitters;
        is scalar(@$tweets), 1, '1 tweet message found';
        is $tweets->[0]{to}, 'lukec', 'to correct user';
        like $tweets->[0]{msg}, qr/It is garbage day on \w+ for [\w\-]+/, 'message is correct';
    }

    WebHooks: {
        # Set up reminder to be able to do another update
        $robj = $model->reminders->by_id($robj->id);
        $robj->target('webhook:http://example.com/your-special-webhook-here');
        $robj->last_notified(0);
        $robj->update;

        my $reminders = $model->notifier->need_notification( as_of => $pud, debug => 1);
        is scalar(@$reminders), 1, 'reminder needs notification again';
        $model->notifier->notify($reminders->[0]);
        my $reqs = t::VanTrash->http_requests;
        is scalar(@$reqs), 1, '1 http request found';
    }
}

done_testing();
exit;
