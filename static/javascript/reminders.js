(function($) {

TrashReminders = function() {}

TrashReminders.prototype = {
    add: function (id, password, email, time_offset) {
    },

    showLightbox: function($node) {
        $("<div>hi</div>").lightbox({
            src: 'http://www.google.com',
            imageClickClose: false
        });
    }
};

})(jQuery);
