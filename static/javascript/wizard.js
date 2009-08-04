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
        var $buttons = $('<div class="buttons"></div>').appendTo(this);
        if (i > opts.firstStep) {
            make_button(opts.backButton)
                .click(function() { showStep(i-1) })
                .appendTo($buttons);
        }
        if (i < self.length-1) {
            make_button(opts.nextButton)
                .click(function() { showStep(i+1) })
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

    function showStep(newStep) {
        $(steps[currentStep]).fadeOut(function() {
            $(steps[newStep]).fadeIn();
            currentStep = newStep;
        });
    }

    var $form = $(this).parents('form');
    if ($form.size()) {
        $form.submit(function() {
            if (currentStep < steps.length-1) {
                showStep(currentStep+1);
            }
            else if (opts.onSubmit) {
                opts.onSubmit();
            };
            return false;
        });
    }

    $($(this).get(currentStep)).show();

    function make_button(src) {
        return $('<a href="#"></a>')
            .addClass('button')
            .append($('<img/>').attr('src', src));
    }
};

})(jQuery);
