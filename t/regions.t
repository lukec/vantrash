#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use t::VanTrash;

No_regions_at_start: {
    my $model = t::VanTrash->model;
    my $regions = $model->regions->all;
    is_deeply $regions, [];
}

Add_a_region: {
    my $model = t::VanTrash->model;
    my $region = $model->regions->add({
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
            kml_file => 'vancouver.kml',
        }
    );
    is $region->name, 'vancouver', 'name';
    is $region->desc, 'Vancouver', 'desc';

    is_deeply $model->regions->all, [
        {
            region_id => 1,
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
            kml_file => 'vancouver.kml',
        },
    ];
}

Region_districts: {
    my $model = t::VanTrash->model;
    my $districts = $model->districts->all;
    is_deeply $districts, [];
}

exit;

Create_a_district: {
    my $model = t::VanTrash->model;
    my $yvr = $model->regions->by_name('vancouver');
    my $district = $model->districts->add({
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
            region => $yvr,
            kml_file => 'vancouver.kml',
        }
    );
    is $district->name, 'vancouver', 'name';
    is $district->desc, 'Vancouver', 'desc';
    is $district->region->name, 'vancouver', 'region name';

    is_deeply $yvr->districts->all, [
        {
            name => 'vancouver',
            desc => 'Vancouver',
            centre => '[ 49.26422,-123.138542 ]',
            kml_file => 'vancouver.kml',
        },
    ];
}

Area_zones_create: {
    my $model = t::VanTrash->model;
    my $yvr = $model->regions->by_name('vancouver');
    my $districts = $yvr->districts->all;
    my $zone_hash = {
        name => 'vancouver-north-blue',
        desc => 'North Blue',
        district => $districts->[0],
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

