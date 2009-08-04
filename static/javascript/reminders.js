(function($) {

TrashReminders = function(opts) {
    $.extend(this, opts)
}

TrashReminders.prototype = {
    add: function (zone, data, callback) {
        data.name = data.name || 'reminder';
        $.ajax({
            type: 'PUT',
            url: '/zones/' + zone + '/reminders',
            data: $.toJSON(data, true),
            complete: function() {
            },
        });
    },

    showLightbox: function($node) {
        $.lightbox({
            src: '/new_reminder-lightbox.html?zone=' + this.zone,
            height: 240,
            widthFactor: 0.4
        });
    }
};

})(jQuery);
