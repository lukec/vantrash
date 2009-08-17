(function($){

var opts = {
    firstStep: 0
};

$.fn.wizard = function() {
    if (arguments.length) $.extend(opts, arguments[0]);

    var steps = this;
    var currentStep = opts.firstStep;

    var self = this;
    $(this).hide().each(function(i) {
        var $form = $(this).parents('form');
        var $buttons = $('<div class="lbButtons"></div>').appendTo(this);
        if (i > opts.firstStep) {
            make_button(opts.backButton, 'back')
                .click(function() { showStep(i-1); return false; })
                .appendTo($buttons);
        }
        if (i < self.length-1) {
            make_button(opts.nextButton, 'next')
                .click(function() { showStep(i+1); return false; })
                .appendTo($buttons);
        }
        if (i+1 == self.length) {
            make_button(opts.submitButton, 'submit')
                .click(function() { $form.submit(); return false; })
                .appendTo($buttons);
        }

        if ($form.size()) {
            $form.submit(function() {
                if (currentStep < steps.length-1) {
                    showStep(currentStep+1);
                }
                else if ($.isFunction(opts.submit)) {
                    opts.submit($form);
                };
                return false;
            });
        }

    });

    function showStep(newStep) {
        $(steps[currentStep]).hide();
        $(steps[newStep]).show();
        currentStep = newStep;
    }

    $($(this).get(currentStep)).show();

    function make_button(src, klass) {
        return $('<a href="#"></a>')
            .addClass('button')
            .addClass(klass)
            .append($('<img/>').attr('src', src));
    }
};

})(jQuery);
