(function($) {
TrashMap = function(opts) {
    if (!arguments.length) opts = {};
    $.extend(this, opts);
}

TrashMap.prototype = {
    dayNames: [ 'Sun','Mon','Tue','Wed','Thu','Fri','Sat' ],
    monthNames: [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sept','Oct','Nov','Dec'
    ],
    descriptions: {},
    zoom: 12,
    center: typeof(GLatLng) != 'undefined'
        ? new GLatLng(49.24702, -123.125542)
        : undefined,

    showSchedule: function(node, name, color) {
        var self = this;

        self.getNextPickup(name, function(next, yard) {
            var $div = $(Jemplate.process('balloon.tt2', {
                description: self.descriptions[name],
                next: next,
                yard: yard
            }));
                
            $div.find('.remind_me', node).button().click(function() {
                var lightbox = new ReminderLightbox({
                    zone: name
                });
                lightbox.show();
            });

            var $node = $div.find('.calendar', node);
            self.createCalendar(name, $node, function(){
                if (!node) throw new Error("Node required");
                if (node.openInfoWindow) {
                    node.openInfoWindow($div.get(0), {maxWidth: 220});
                }
                else {
                    var center = node.getBounds().getCenter();
                    self.map.openInfoWindow(
                        center, $div.get(0), {maxWidth: 220}
                    );
                }
            });
        });
    },

    getNextPickup: function(name, callback) {
        var self = this;
        $.getJSON('/zones/' + name + '/nextpickup.json', function (next) {
            var yard = '';
            next = next.next[0];
            if (next.match(/^(\d+)-(\d+)-(\d+)(?: (Y))?/)) {
                var nextDate = new Date;
                nextDate.setFullYear(RegExp.$1);
                nextDate.setMonth(RegExp.$2-1);
                nextDate.setDate(RegExp.$3);
                next = [
                    self.dayNames[nextDate.getDay()],
                    self.monthNames[nextDate.getMonth()],
                    nextDate.getDate(),
                    nextDate.getFullYear()
                ].join(' ');
                yard = RegExp.$4
                    ? ' (Yard trimmings will be picked up)'
                    : ' (Yard trimmings will NOT be picked up)'
            }
            callback(next, yard);
        });
    },

    createCalendar: function(name, $node, cb) {
        $.getJSON('/zones/' + name + '/pickupdays.json', function (days) {
            /* Make a hash of days */
            var pickupdays = {};
            var yarddays = {};
            $.each(days, function(i,d) {
                var key = [d.year,Number(d.month),Number(d.day)].join('-');
                pickupdays[key] = true;
                if (d.flags == 'Y') {
                    yarddays[key] = true
                }
            });

            $node.datepicker({
                beforeShowDay: function(day) {
                    var key = [
                        day.getFullYear(), day.getMonth()+1, day.getDate()
                    ].join('-');
                    var className = 'day';
                    if (pickupdays[key]) className += ' marked';
                    if (yarddays[key]) className += ' yard';
                    return [ false, className ];
                }
            });

            if (cb) cb();
        });
    },

    createMap: function(node) {
        this.map = new GMap2(node);
        this.map.setUIToDefault();
        this.map.setCenter(this.center,this.zoom);
    },

    render: function(node) {
        var self = this;
        this.createMap(node);
        this.loadKML(function() {
            if (self.startingZone) {
                self.showScheduleForZone(self.startingZone);
            }
            else {
                self.showScheduleForCurrentLocation();
            }
            self.map.setCenter(self.center,self.zoom);
        });
    },

    showScheduleForZone: function(zone_name) {
        var self = this;
        var matchedZone;
        $.each(this.zones, function(i,zone) {
            if (zone.name == zone_name) {
                matchedZone = zone;
            }
        });
        if (matchedZone) {
            self.showSchedule(matchedZone, matchedZone.name, matchedZone.color);
        }
        else {
            throw new Error("Can't find zone!");
        }
    },

    showScheduleForLocation: function (latlng) {
        var zone = this.containingZone(latlng);
        if (zone) {
            if (this.marker) this.map.removeOverlay(this.marker);
            this.marker = new GMarker(latlng, {
                icon: this.createHomeIcon()
            });
            this.map.addOverlay(this.marker);
            this.map.setCenter(latlng);

            this.showSchedule(this.marker, zone.name, zone.color);
        }
    },

    containingZone: function (latlng) {
        var containingZone;

        $.each(this.zones, function(i,zone) {
            if (zone.Contains(latlng)) {
                containingZone = zone;
            }
        });
        return containingZone;
    },

    showScheduleForCurrentLocation: function () {
        var self = this;
        this.findCurrentLocation(function(lat, lng) {
            var latlng = new GLatLng(lat, lng);
            self.showScheduleForLocation(latlng);
        });
    },

    findCurrentLocation: function (callback) {
        var self = this;
        
        // Try W3C Geolocation (Preferred)
        if (navigator.geolocation) {
            navigator.geolocation.watchPosition(
                function(position) {
                    callback(
                        position.coords.latitude, position.coords.longitude
                    );
                }, function() {
                    // error
                }
            );
        }
        // Try Google Gears Geolocation
        else if (google.gears) {
            var geo = google.gears.factory.create('beta.geolocation');
            geo.getCurrentPosition(
                function(position) {
                    callback(position.latitude,position.longitude);
                }, function() {
                    // error
                }
            );
        }
        // Browser doesn't support Geolocation
        else {

        }
    },

    loadKML: function(callback) {
        var self = this;
        this.zones = [];
        this.exml = new EGeoXml("exml", this.map, "/zones.kml", {
            createpolygon: function (pts,sc,sw,so,fc,fo,pl,name,desc) {
                var zone = new GPolygon(pts, sc, sw, so, fc, fo);
                GEvent.addListener(zone, 'click', function() {
                    self.showSchedule(zone, name, fc);
                    return false;
                });
                zone.name = name;
                self.descriptions[name] = desc;
                self.zones.push(zone);
                self.map.addOverlay(zone);
            }
        });
        GEvent.addListener(this.exml, 'parsed', function() {
            self.bounds = self.map.getBounds();
            if ($.isFunction(callback)) { callback() };
        });
        this.exml.parse();
    },

   /* Google Map Custom Marker Maker 2009
    * Please include the following credit in your code
    *
    * Sample custom marker code created with Google Map Custom Marker Maker
    * http://www.powerhut.co.uk/googlemaps/custom_markers.php
    */
    createHomeIcon: function() {
        var myIcon = new GIcon();
        var myIcon = new GIcon();
        myIcon.image = '/images/homeIcon.png';
        myIcon.printImage = '/images/homeIconPrint.gif';
        myIcon.mozPrintImage = '/images/homeIconMozPrint.gif';
        myIcon.iconSize = new GSize(20,20);
        myIcon.shadow = '/images/homeIconShadow.png';
        myIcon.transparent = '/images/homeIconTransparent.png';
        myIcon.shadowSize = new GSize(30,20);
        myIcon.printShadow = '/images/homeIconPrintShadow.gif';
        myIcon.iconAnchor = new GPoint(10,20);
        myIcon.infoWindowAnchor = new GPoint(10,0);
        myIcon.imageMap = [15,0,15,1,15,2,15,3,15,4,16,5,17,6,18,7,19,8,19,9,16,10,16,11,16,12,16,13,16,14,16,15,16,16,16,17,16,18,3,18,3,17,3,16,3,15,3,14,3,13,3,12,3,11,3,10,0,9,0,8,1,7,2,6,3,5,5,4,6,3,7,2,8,1,9,0];
        return myIcon;
    },

    search: function(address) {
        var self = this;
        if (!this.bounds) return;
        if (!address.match(/vancouver/i)) address += ', Vancouver';
        var geocoder = new GClientGeocoder();
        geocoder.setViewport(this.map.getBounds());
        geocoder.setBaseCountryCode('ca');
        geocoder.getLatLng(address, function(point) {
            if (! point) {
                alert("Not found");
            }
            else {
                if (self.bounds.contains(point)) {
                    self.showScheduleForLocation(point);
                }
                else {
                    alert("Sorry, I couldn't find that address within this map view. Please try again"); 
                }
            }
        });
    },

    logClicks: function() {
        $('body').append(
            $('<a href="#">clear</a>')
                .click(function() { $('#clicks').empty() })
        );
        $('body').append('<div id="clicks"></div>');
        GEvent.addListener(this.map, 'click', function(o, latlng) {
            if (latlng) {
                $('#clicks').append(latlng.x+', '+latlng.y+', 0<br/>');
            }
        });
    }
}

})(jQuery);
