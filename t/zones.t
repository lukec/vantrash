#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use t::VanTrash;

$ENV{VT_LOAD_DATA} = 1;

Set_now_time: {
    my $model = t::VanTrash->model;

    # Set the time to right before a day change
    my $now = $model->now;
    $now->set(
        month => 9,
        day => 1,
        year => 2009,
    );
    $ENV{VANTRASH_NOW} = $now;
}

Next_pickup: {
    my $model = t::VanTrash->model;
    my $np = $model->next_pickup('vancouver-south-red', 1, 'datetime');
    is $np->ymd, '2009-09-03', 'next-pickup';
}

Next_dow_change: {
    my $model = t::VanTrash->model;
    my %days = $model->next_dow_change('vancouver-south-red');
    is $days{last},  '1251961200', 'next-day-change';
    is $days{first}, '1252652400', 'next-day-change';
    $ENV{VANTRASH_NOW}->set( day => 11 );
    %days = $model->next_dow_change('vancouver-south-red');
    is $days{last},  '1255071600', 'next-day-change';
    is $days{first}, '1255935600', 'next-day-change';
}


done_testing();
exit;

