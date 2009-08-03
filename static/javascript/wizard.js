(function($){

var opts = {
    firstSlide: 0
};

$.fn.wizard = function() {
    if (arguments.length) $.extend(opts, arguments[0]);

    var self = this;
    $(this).hide().each(function(i) {
        var $buttons = $('<div class="buttons"></div>').appendTo(this);
        if (i > opts.firstSlide) {
            make_button(opts.backButton)
                .click(function() {
                    slide(i).fadeOut(function() {
                        slide(i-1).fadeIn();
                    });
                })
                .appendTo($buttons);
        }
        if (i < self.length-1) {
            make_button(opts.nextButton)
                .click(function() {
                    slide(i).fadeOut(function() {
                        slide(i+1).fadeIn();
                    });
                })
                .appendTo($buttons);
        }
        else {
            make_button(opts.submitButton)
                .click(function() {
                    $(this).parents('form').submit();
                })
                .appendTo($buttons)
        }
    });

    $($(this).get(opts.firstSlide)).show();

    var slides = this;
    function slide(i) {
        return $(slides[i]);
    }

    function make_button(src) {
        return $('<a href="#"></a>')
            .addClass('button')
            .append($('<img/>').attr('src', src));
    }
};

})(jQuery);
