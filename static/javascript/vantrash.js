(function($) {

Vantrash = function() {
}

Vantrash.prototype = {
    center: [ 49.26422,-123.138542 ],

    showInfo: function(latlng, html) {
        this.map.openInfoWindow(latlng, html);
    },

    showSchedule: function(latlng, name, clr, opac) {
        var self = this;
        $.getJSON('/zones/' + name + '/pickupdays.json', function (data) {
            var cal = new Calendar;
            var table = cal.create();
            $.each(data, function(i,d) { cal.mark(d) });
            cal.show();
            $('.marked', table).css({
                backgroundColor: clr,
                opacity: opac
            });
            self.showInfo(latlng, table.get(0));
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
                    self.showSchedule(center, name, sc, so);
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
