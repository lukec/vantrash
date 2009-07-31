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
        'January', 'Febuary', 'March', 'April', 'May', 'June',
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
            .click(function() { self.prevMonth() })
            .appendTo($('<td></td>').appendTo($tr));
        $('<td>month</td>')
            .attr('colspan', 5)
            .addClass('month')
            .appendTo($tr);
        $('<a href="#"></a>')
            .text('>>')
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
            .css('background-color', '')
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

            if (this.isMarked(cnt)) {
                $cell.addClass('marked');
                if (this.markColor) {
                    $cell.css('background-color', this.markColor);
                }
            }
            if (this.areSameDay(cnt, today)) {
                $cell.addClass('today');
            }

            cnt.setDate(cnt.getDate()+1);
        }
    },

    mark: function(d) {
        this.markers.push(this.parseDate(d));
    },

    isMarked: function(d) {
        var self = this;
        if (!this.markers.length) return 0;
        var length = $.grep(this.markers, function (date) {
            return self.areSameDay(date, d);
        }).length;
        return length;
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
            var marked = this.markers[i];
            if (marked.getTime() > today.getTime()) return marked
            if (this.areSameDay(today, marked)) return marked;
        }
    }

};

})(jQuery);
