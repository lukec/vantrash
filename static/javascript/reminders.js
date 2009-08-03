(function($) {

TrashReminders = function(opts) {
    $.extend(this, opts)
}

TrashReminders.prototype = {
    add: function (id, password, email, time_offset) {
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
