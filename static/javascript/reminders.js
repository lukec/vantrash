(function($) {

TrashReminders = function(opts) {
    $.extend(this, opts)
}

TrashReminders.prototype = {
    add: function (opts) {
        var data = {
            name: opts.name || 'reminder',
            email: opts.email,
            offset: opts.offset
        };
        $.ajax(
            $.extend({
                type: 'PUT',
                url: '/zones/' + opts.zone + '/reminders',
                data: $.toJSON(data, true)
            }, opts)
        );
    },

    showLightbox: function($node) {
        $.lightbox({
            src: '/new_reminder.html?lightbox=1&zone=' + this.zone,
            widthFactor: 0.4
        });
    }
};

})(jQuery);
