(function($) {

TrashMap = function(opts) {
    if (!arguments.length) opts = {};
    $.extend(this, opts);
}

TrashMap.prototype = {
    descriptions: {},
    center: function() {
        return new GLatLng(49.26422, -123.138542);
    },

    getZoneInfo: function(name, color, callback) {
        var self = this;
        $.getJSON('/zones/' + name + '/pickupdays.json', function (days) {
            var cal = new Calendar();
            $.each(days, function(i,d) {
                cal.mark(new CalendarMarker({
                    year: d.year,
                    month: d.month,
                    day: d.day,
                    color: color,
                    image: d.flags == 'Y' ? '/images/yard.png' : false
                }))
            });
            cal.draw();
            cal.createLegend({
                'Garbage day': { color: color },
                'Yard pickup': { color: color, image: '/images/yard.png' }
            });
            callback(self.createInfoNode(cal, name));
        });
    },

    createInfoNode: function (cal, name) {
        var $div = $('<div class="balloon"></div>')

        // Zone Title
        $div.append(
            $('<div class="zoneName"></div>') .text(this.descriptions[name])
        );

        // Next pickup date
        var nextDay = cal.nextMarkedDate();
        if (nextDay) {
            var days = cal.daysUntil(nextDay);
            $div.append(
                $('<div class="next"></div>').append(
                    $('<span class="title"></span>').text('Next pickup: '),
                    $('<span class="day"></span>')
                        .text(days == 1 ? 'Tomorrow' : cal.formatDate(nextDay))
                )
            );
        }

        // Zone pickup schedule calendar
        $div.append(cal.getTable());

        $div.append(cal.getLegend());

        // Buttons
        $div.append(
            $('<div class="buttons"></div>').append(
                $('<input type="button" class="smallbtn"/>')
                    .val("Add to calendar")
                    .click(function() {
                        location = "webcal://"
                                 + location.host
                                 + '/zones/' + name + '/pickupdays.ics';
                    }),
                $('<input type="button" class="smallbtn"/>')
                    .val('Remind me')
                    .click(function() {
                        var reminders = new TrashReminders({zone: name});
                        reminders.showLightbox();
                        return false;
                    })
            )
        );

        return $div.get(0);
    },

    showSchedule: function(node, name, color) {
        var self = this;

        this.getZoneInfo(name, color, function(result) {
            if (!node) throw new Error("Node required");
            if (node.openInfoWindow) {
                node.openInfoWindow(result);
            }
            else {
                var center = node.getBounds().getCenter();
                self.map.openInfoWindow(center, result);
            }
        });
    },

    render: function(node) {
        var self = this;
        this.map = new GMap2(node);
        this.map.setCenter(this.center(),9);
        this.map.setUIToDefault();
        this.loadKML(function() {
            self.bounds = self.map.getBounds();
            self.setCurrentLocation();
        });
    },

    loadKML: function(callback) {
        var self = this;
        this.zones = [];
        this.exml = new EGeoXml("exml", this.map, "zones.kml", {
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

    showScheduleForLocation: function (latlng) {
        var marker = new GMarker(latlng, {
            icon: this.createHomeIcon()
        });
        this.map.addOverlay(marker);
        this.map.setCenter(latlng);

        var self = this;
        $.each(this.zones, function(i,zone) {
            if (zone.Contains(latlng)) {
                self.showSchedule(marker, zone.name, zone.color);
            }
        });
    },

    setCurrentLocation: function () {
        var self = this;
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(function(position) {
                if (self._done_curloc) return;
                self._done_curloc = true;
                self.showScheduleForLocation(new GLatLng(
                    position.coords.latitude, position.coords.longitude
                ));
            });
        }
    },

    findLocation: function(address) {
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
