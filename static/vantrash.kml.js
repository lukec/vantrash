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
        var parts = d.split('-');
        var dateobj = new Date;
        dateobj.setYear(parts[0]);
        dateobj.setMonth(parts[1]-1);
        dateobj.setDate(parts[2]);
        return dateobj;
    },

    showInfo: function(latlng, html) {
        this.map.openInfoWindow(latlng, '<br/>' + html);
    },

    showSchedule: function(name, latlng) {
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
            new GLatLng(this.center[0], this.center[1]), 12
        );
        this.loadKML();
    },

    loadKML: function(url) {
        this.map.clearOverlays();
        if (!url) url = "http://vantrash.ca/zones1.kml";
        this.geoxml = new GGeoXml(url);
        this.map.addOverlay(this.geoxml);
        this.geoxml.gotoDefaultViewport(this.map);

        /*
        GEvent.addListener(polygon, 'click', function(latlng) {
            self.showSchedule(name, latlng);
        });

        this.setCurrentLocation();
        */
    },

    addClickHandler: function() {
        GEvent.addListener(this.map, 'click', function(overlay, latlng) {
            if (latlng) {
                $('#clicks').append('['+latlng.y+', '+latlng.x+'], ');
            }
        });
    },

    setCurrentLocation: function () {
        var self = this;
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(function(position) {
                if (self._doneloc) return;
                self._doneloc = true;
                var point = new GLatLng(position.coords.latitude, position.coords.longitude);
                $.each(self.polygons, function(name, polygon) {
                    if (polygon.getBounds().contains(point)) {
                        self.map.addOverlay(new GMarker(point));
                        self.showSchedule(name, point);
                    }
                });
            });
        }
    }
}

})(jQuery);
