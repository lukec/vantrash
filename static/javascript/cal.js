(function($){

Calendar = function (args) {
    $.extend(this, args, {
        date: new Date,
        markers: []
    });
    this.setup();
}

Calendar.prototype = {
    days: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    months: [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    ],
    ROWS: 2 + Math.ceil(31 / 7),

    getTable: function() {
        return this.table;
    },

    nextMonth: function () {
        this.date.setMonth(this.date.getMonth()+1);
        this.draw();
    },

    prevMonth: function () {
        this.date.setMonth(this.date.getMonth()-1);
        this.draw();
    },

    setup: function () {
        var self = this;

        this.table = $('<table></table>').addClass('calendar').get(0);

        /* Month / Year row */
        var $tr = $('<tr></tr>').appendTo(this.table);
        $('<a href="#"></a>')
            .text('<<')
            .addClass('back')
            .click(function() { self.prevMonth() })
            .appendTo($('<td></td>').appendTo($tr));
        $('<td>month</td>')
            .attr('colSpan', '5')
            .addClass('month')
            .appendTo($tr);
        $('<a href="#"></a>')
            .text('>>')
            .addClass('forward')
            .click(function() { self.nextMonth() })
            .wrap('<td></td>')
            .appendTo($('<td></td>').appendTo($tr));

        /* Day of week row */
        var $daysRow = $('<tr></tr>').appendTo(this.table);
        $.each(this.days, function(i, day) {
            $('<td></td>').text(day).appendTo($daysRow);
        });

        this.cells = [];

        // Create the day cells
        for (var row=0; row < this.ROWS; row++) {
            var $tr = $('<tr></tr>').appendTo(this.table);
            for (var day=0; day < 7; day++) {
                $('<td></td>').appendTo($tr);
            }
        }
    },

    draw: function() {
        $('.day', this.table)
            .html('')
            .css('background', '')
            .removeClass('today')
            .removeClass('marked');

        var cnt = new Date(this.date.getTime());
        var month = cnt.getMonth();

        $('.month', this.table)
            .text(this.months[month] + '/' + cnt.getFullYear());

        cnt.setDate(1);
        var firstDay = cnt.getDay();

        var today = new Date;

        $('td.day', this.table).removeClass('day')
        while (cnt.getMonth() == month) {
            var rowNum = Math.floor((firstDay + cnt.getDate() - 1) / 7) + 2;
            var row = $('tr',this.table).get(rowNum)
            var $cell = $( $('td', row).get(cnt.getDay()) );

            var cellDate = cnt.getDate()
            $cell.addClass('day').html(cellDate);

            var marker = this.getMarker(cnt);
            if (marker) {
                $cell.addClass('marked');
                this.applyStyle($cell, marker);
            }
            if (this.areSameDay(cnt, today)) {
                $cell.addClass('today');
            }

            cnt.setDate(cnt.getDate()+1);
        }
    },

    mark: function(marker) {
        this.markers.push(marker);
    },

    getMarker: function(d) {
        var self = this;
        if (!this.markers.length) return false;
        for (var i=0; i<this.markers.length; i++) {
            var marker = this.markers[i];
            var marked =
                d.getDate() == marker.day &&
                d.getMonth() == marker.month-1 &&
                d.getFullYear() == marker.year;
            if (marked) return marker;
        }
        return false;
    },

    daysUntil: function(d) {
        var counter = new Date; // today

        var max_days = 20;
        var days = 0;
        while (!this.areSameDay(counter,d)) {
            counter.setDate(counter.getDate()+1);
            days++;
            if (days > 10) return -1;
        }
        return days;
    },

    areSameDay: function (a, b) {
        return a.getDate() == b.getDate()
            && a.getMonth() == b.getMonth()
            && a.getYear() == b.getYear();
    },

    parseDate: function(d) {
        var dateobj = new Date;
        dateobj.setYear(d.year);
        dateobj.setMonth(d.month-1);
        dateobj.setDate(d.day);
        return dateobj;
    },

    formatDate: function(d) {
        return String(d).replace(/ \d+:\d+.*/, '');
    },

    nextMarkedDate: function() {
        var today = new Date;
        for (var i=0; i<this.markers.length; i++) {
            var marked = this.parseDate(this.markers[i]);
            if (marked.getTime() > today.getTime()) return marked
            if (this.areSameDay(today, marked)) return marked;
        }
    },

    applyStyle: function($cell, style) {
        if (style.image) {
            $cell.css(
                'background',
                'url('+style.image+')' + ' top left no-repeat'
            );
        }
        if (style.color) {
            $cell.css('background-color', style.color);
        }
        return $cell;
    },

    createLegend: function(legend) {
        var self = this;
        this.legend = $('<div></div>').addClass('legend');
        var $table = $('<table></table>').appendTo(this.legend);
        $.each(legend, function(key,item) {
            var $tr = $('<tr></tr>').appendTo($table);
            self.applyStyle(
                $('<td></td>').addClass('key').appendTo($tr),
                item
            );
            $('<td class="label"></td>').text(key).appendTo($tr);
            $('<tr><td class="padding"></td></tr>').appendTo($table);
        });
    },

    getLegend: function() {
        return this.legend;
    }

};

CalendarMarker = function(args) {
    $.extend(this, args, {});
}

CalendarMarker.prototype = {};

})(jQuery);
