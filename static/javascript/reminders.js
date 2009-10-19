(function($) {

TrashReminders = function(opts) {
    $.extend(this, opts)
}

TrashReminders.prototype = {
    add: function (opts) {
        var data = {
            offset: opts.offset,
            email: opts.email,
            name: "reminder" + (new Date).getTime(),
            target: opts.target
        };
        $.ajax({
            type: 'PUT',
            url: '/zones/' + opts.zone + '/reminders',
            data: $.toJSON(data, true),
            error: opts.error,
            success: opts.success
        });
    },

    showLightbox: function($node) {
        $.lightbox({
            src: '/reminder_new1.html?lightbox=1&zone=' + this.zone,
            widthFactor: 0.4,
            height: 220
        });
    }
};

})(jQuery);
