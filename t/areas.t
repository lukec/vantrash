#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use t::VanTrash;

No_areas_at_start: {
    my $model = t::VanTrash->model;
    my $areas = $model->areas->all;
    is_deeply $areas, [];
}

Add_an_area: {
    my $model = t::VanTrash->model;
    my $area = $model->areas->add({
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
        }
    );
    is $area->name, 'vancouver', 'name';
    is $area->desc, 'Vancouver', 'desc';

    is_deeply $model->areas->all, [
        {
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
        },
    ];
}

Area_zones: {
    my $model = t::VanTrash->model;
    my $zones = $model->zones->all;
    is_deeply $zones, [];
}

Area_zones_create: {
    my $model = t::VanTrash->model;
    my $zone_hash = {
        name => 'vancouver-north-blue',
        desc => 'North Blue',
        area => 'vancouver',
        colour => 'blue',
    };
    $model->zones->add({
            %$zone_hash,
            days => [
                '2009-01-01',
                '2009-02-02 Y',
            ],
        },
    );

    my $expected = [ $zone_hash ];
    is_deeply $model->zones->all, $expected, 'all zones';
    my $van_zones = $model->zones->by_area('vancouver');
    $_ = $_->to_hash() for @$van_zones;
    is_deeply $van_zones, $expected, 'zones by_area';

    my $pickups = $model->pickups->by_zone($zone_hash->{name});
    is_deeply $pickups, [
        {
            zone => $zone_hash->{name},
            string => '2009-01-01',
            flags => '',
            year => 2009, month => '01', day => '01',
        },
        {
            zone => $zone_hash->{name},
            string => '2009-02-02 Y',
            flags => 'Y',
            year => 2009, month => '02', day => '02',
        },
    ], 'pickups by zone';
}

done_testing();
exit;

