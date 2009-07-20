(function($){

Calendar = function () {
    $.extend(this, {
        date: new Date,
        markers: []
    });
}

Calendar.prototype = {
    ROWS: 2 + Math.ceil(31 / 7),

    // Extract the names of the months and days for internationalization
    getNames: function () {
        var date = new Date;

        // create an array with the names of the months
        this.months = [];
        for (var i=0; i<12; i++) {
            date.setMonth(i);
            this.months.push(date.toString().split(' ')[1]);
        }

        // create an array with the names of the months
        this.days = [];

        // find monday
        for (var i = date.getDate(); date.getDay(); i++) {
            date.setDate(i);
        }

        // set the names
        for (var i=date.getDate(); this.days.length < 7; i++) {
            date.setDate(i);
            this.days.push(date.toString().split(' ')[0]);
        }
    },

    nextMonth: function () {
        this.date.setMonth(this.date.getMonth()+1);
        this.show();
    },

    prevMonth: function () {
        this.date.setMonth(this.date.getMonth()-1);
        this.show();
    },

    create: function () {
        var self = this;
        if (!this.days || !this.month) {
            this.getNames();
        }

        this.table = $('<table></table>').addClass('calendar');
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

        this.cells = [];

        // Create the day cells
        for (var row=0; row < this.ROWS; row++) {
            var $tr = $('<tr></tr>').appendTo(this.table);
            for (var day=0; day < 7; day++) {
                $('<td></td>')
                    .addClass('day')
                    .appendTo($tr);
            }
        }

        this.show();

        return this.table;
    },

    show: function() {
        $('.day', this.table)
            .html('')
            .removeClass('today')
            .removeClass('marked');

        var cnt = new Date(this.date.getTime());
        var month = cnt.getMonth();

        $('.month', this.table)
            .text(this.months[month] + '/' + cnt.getFullYear());

        cnt.setDate(1);
        var firstDay = cnt.getDay();

        var today = new Date;

        while (cnt.getMonth() == month) {
            var row = Math.floor((firstDay + cnt.getDate() - 1) / 7) + 1;
            var $cell
                = $($('td', $('tr',this.table).get(row)).get(cnt.getDay()));

            var cellDate = cnt.getDate()
            $cell.addClass(String(cellDate)).html(cellDate);

            if (this.isMarked(cnt)) {
                $cell.addClass('marked');
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
        var parts = d.split('-');
        var dateobj = new Date;
        dateobj.setYear(parts[0]);
        dateobj.setMonth(parts[1]-1);
        dateobj.setDate(parts[2]);
        return dateobj;
    }
};

})(jQuery);
