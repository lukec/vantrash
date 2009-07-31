(function($) {

TrashReminders = function() {}

TrashReminders.prototype = {
    add: function (id, password, email, time_offset) {
    },

    showLightbox: function($node) {
        $.lightbox({
            src: '/new_reminder-lightbox.html',
            height: 80,
            widthFactor: 0.4
        });
    }
};

})(jQuery);
