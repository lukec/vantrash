(function($) {

Vantrash = function() {
}

Vantrash.prototype = {
    center: [ 49.26422,-123.138542 ],
    daysUntil: function(d) {
        var counter = new Date; // today
        function sameday (a, b) {
            return a.getDate() == b.getDate()
                && a.getMonth() == b.getMonth()
                && a.getYear() == b.getYear();
        }

        var max_days = 20;
        var days = 0;
        while (!sameday(counter,d)) {
            counter.setDate(counter.getDate()+1);
            days++;
            if (days > 10) return -1;
        }
        return days;
    },

    formattedDate: function(d) {
        return d.toString().replace(/ \d+:\d+:.*/,'');
    },

    parseDate: function(d) {
        var parts = d[0].split('-');
        var dateobj = new Date;
        dateobj.setYear(parts[0]);
        dateobj.setMonth(parts[1]-1);
        dateobj.setDate(parts[2]);
        return dateobj;
    },

    showInfo: function(latlng, html) {
        this.map.openInfoWindow(latlng, '<br/>' + html);
    },

    showSchedule: function(latlng, name) {
        var self = this;
        $.getJSON('/zones/' + name + '/nextpickup.json', function (data) {
            var next = self.parseDate(data.next);
            var days = self.daysUntil(next);

            if (days == -1) {
                self.showInfo(latlng, 'Next pickup on ' + self.formattedDate(next));
            }
            else if (days == 1) {
                self.showInfo(
                    latlng, 'Next pickup <strong>tomorrow</strong> on ' + self.formattedDate(next)
                );
            }
            else {
                self.showInfo(
                    latlng, 'Next pickup in ' + days + ' days on ' + self.formattedDate(next)
                );
            }
        });
    },

    render: function(node) {
        var self = this;
        this.map = new GMap2(node);
        this.map.setCenter(
            new GLatLng(this.center[0], this.center[1]), 13
        );
        this.loadKML();
    },

    loadKML: function(url) {
        var self = this;
        this.zones = [];
        this.exml = new EGeoXml("exml", this.map, "zones.kml", {
            createpolygon: function (pts,sc,sw,so,fc,fo,pl,name) {
                var zone = new GPolygon(pts, sc, sw, so, fc, fo);
                GEvent.addListener(zone, 'click', function() {
                    var center = zone.getBounds().getCenter()
                    self.showSchedule(center, name);
                    return false;
                });
                self.zones.push(zone);
                self.map.addOverlay(zone);
            }
        });
        GEvent.addListener(this.exml, 'parsed', function() {
            self.setCurrentLocation();
        });
        this.exml.parse();
    },

    setCurrentLocation: function () {
        var self = this;
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(function(position) {
                if (self._location) return;
                self._location = new GLatLng(
                    position.coords.latitude, position.coords.longitude
                );
                self.map.addOverlay(new GMarker(self._location));
                $.each(self.zones, function(i, zone) {
                    if (zone.Contains(self._location)) {
                        GEvent.trigger(zone, 'click');
                        self._clicked_curloc = true;
                    }
                });
            });
        }
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
