(function($) {

ReminderWizard = function() { }

ReminderWizard.prototype = {
    setup: function() {
        var self = this;

        var $target = $('input[name=target]');
        function fromEmail() { $target.val('email:' + $(this).val()) }
        function fromTwitter() { $target.val('twitter:' + $(this).val()) }
        $("#emailRadio")
            .click(function() {
                $("input.twitter").attr("disabled", true);
                $('input.email').change(fromEmail).change();
            })
            .click();

        $("#twitterRadio")
            .click(function() {
                $("input.twitter").attr("disabled", false).focus();
                if (!$("input.twitter").val()) {
                    $("input.twitter").val('@');
                }
                $('input.twitter').change(fromTwitter).change();
                $('input.email').change(function() {});
            });

        // Updating #email affects #emailto
        $('.email').change(function(){
            $('.emailto').text($(this).val());
        });

        $('#simpleOffset').change(function() {
            if ($(this).val() == 'custom') {
                $(this).hide();
                $('#customOffset').show();
            }
            else {
                $('#customOffset').val($(this).val());
            }
        }).trigger('change');

        $('#reminderForm').submit(function() {
            try {
                if (self.currentSlide() == 'time_slide') {
                    self.submit()
                }
                else {
                    self.next();
                }
            }
            catch(e) {
                self.showError(e.message);
            }
            return false;
        });
    },

    showError: function(err) {
        var $div = $('<div></div>')
            .text(err)
            .height(0)
            .appendTo('#error')
            .animate({height: '20px'}, 'slow');
        setTimeout(function() {
            $div.animate(
                { height: '0px' },
                'slow', 'swing', function() { $div.remove() }
            );
        }, 2000);
    },

    slides: function() {
        this._slides = this._slides
             || $('.wizard .slide').map(function() { return this.id });
        return this._slides;
    },

    next: function () {
        var slides = this.slides();
        var curidx = slides.index(this.currentSlide());
        this.showSlide(slides[curidx + 1]);
    },

    prev: function () {
        var slides = this.slides();
        var curidx = slides.index(this.currentSlide());
        this.showSlide(slides[curidx - 1]);
    },

    showSlide: function(id) {
        // Hide the error
        $('#error').text('');

        if (this.currentSlide() == 'target_slide') {
            var target = $('input[name=target]').val()
                .replace(/^twitter:\@/, 'twitter:');
            if (target == 'twitter:') {
                return this.showError(
                    'You must provide a valid twitter username'
                );
            }
        }
        else if (this.currentSlide() == 'email_slide') {
            if (!$('input.email').val().match(/^.+@.+$/)) {
                return this.showError(
                    'You must provide a valid email address'
                );
            }
        }

        // Show the next slide
        $('.wizard .current').removeClass('current');
        $('#'+id).addClass('current');
    },

    currentSlide: function() {
        return $('.wizard .slide:visible').attr('id');
    },

    submit: function() {
        var self = this;
        var reminders = new TrashReminders();
        reminders.add({
            offset: $('select[name=offset]').val(),
            zone: $('input[name=zone]').val(),
            email: $("input.email").val(),
            target: $("input[name=target]").val(),
            success: function() {
                self.showSlide('success');
            },
            error: function(req) {
                self.showError(req.responseText);
            }
        });
    }
};
})(jQuery);
