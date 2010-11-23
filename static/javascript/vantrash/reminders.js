(function($) {

ReminderLightbox = function(opts) {
    $.extend(this, this._defaults, opts);
    if (!this.zone) throw new Error("zone is required");
}

ReminderLightbox.prototype = {
    _defaults: {
        reminder: {}
    },

    wizard: function() {
        var self = this;
        if (self._wizard) return self._wizard;
        var reminder = self.reminder;
        return self._wizard = {
            choose_method: {
                next: function() {
                    self.showPage(self.getValue('reminder-radio'))
                }
            },
            premium_sms: {
                focus: '.phone',
                back: function() { self.showPage('choose_method') },
                submit: function($cur) {
                    self.showPage('loading');
                    self.addReminder({
                        offset: $cur.find('.customOffset').val(),
                        email: $cur.find('.email').val(),
                        target: 'sms:' + $cur.find('.phone').val(),
                        payment_period: $cur.find('.paymentPeriod').val(),
                        zone: self.zone,
                        success: function(res) {
                            window.location = res.payment_url;
                        }
                    });
                },
                validate: {
                    rules: {
                        phone: 'required',
                        email: {
                            required: true,
                            email: true
                        }
                    },
                    messages: {
                        phone: 'Please enter your telephone number',
                        email: 'Please enter a valid email'
                    }
                }
            },
            premium_phone: {
                focus: '.phone',
                back: function() { self.showPage('choose_method') },
                submit: function($cur) {
                    self.showPage('loading');
                    self.addReminder({
                        offset: $cur.find('.customOffset').val(),
                        email: $cur.find('.email').val(),
                        target: 'voice:' + $cur.find('.phone').val(),
                        payment_period: $cur.find('.paymentPeriod').val(),
                        zone: self.zone,
                        success: function(res) {
                            window.location = res.payment_url;
                        }
                    });
                },
                validate: {
                    rules: {
                        phone: 'required',
                        email: {
                            required: true,
                            email: true
                        }
                    },
                    messages: {
                        phone: 'Please enter your telephone number',
                        email: 'Please enter a valid email'
                    }
                }
            },
            basic_email: {
                focus: '.email',
                back: function() { self.showPage('choose_method') },
                submit: function($cur) {
                    self.showPage('loading');
                    self.addReminder({
                        offset: $cur.find('.customOffset').val(),
                        email: $cur.find('.email').val(),
                        target: 'email:' + $cur.find('.email').val(),
                        zone: self.zone,
                        success: function() {
                            self.showPage('success');
                        }
                    });
                },
                validate: {
                    rules: {
                        email: {
                            required: true,
                            email: true
                        }
                    },
                    messages: {
                        email: 'Please enter a valid email'
                    }
                }
            },
            basic_twitter: {
                focus: '.twitter',
                back: function() { self.showPage('choose_method') },
                submit: function($cur) {
                    self.showPage('loading');
                    self.addReminder({
                        offset: $cur.find('.customOffset').val(),
                        email: $cur.find('.email').val(),
                        target: 'twitter:' + $cur.find('.twitter').val(),
                        zone: self.zone,
                        success: function() {
                            self.showPage('success');
                        }
                    });
                },
                validate: {
                    rules: {
                        twitter: 'required',
                        email: {
                            required: true,
                            email: true
                        }
                    },
                    messages: {
                        twitter: 'Please enter your twitter username',
                        email: 'Please enter a valid email'
                    }
                }
            }
        };
    },

    getValue: function(name) {
        return this.$dialog.find('input[name=' + name + ']:checked').val()
    },

    templateVars: function() {
        var url = location.href + 'zones/' + this.zone + '/pickupdays.ics';
        return {
            calendars: [
                {
                    name: 'Google Calendar',
                    url: 'http://www.google.com/calendar/render?cid=' + url,
                    icon: 'google.png',
                    id: 'cal-google'
                },
                {
                    name: 'iCal',
                    url: url.replace('http:', 'webcal:'),
                    icon: 'ical.png',
                    id: 'cal-ical'
                },
                {
                    name: 'Microsoft Outlook',
                    url: url,
                    icon: 'outlook.png',
                    id: 'cal-outlook'
                }
            ]
        };
    },

    show: function() {
        if (this.$dialog) throw new Error('Already started wizard!');
        this.$dialog = $('<div></div>').attr('title', 'Add a reminder')
            .html(Jemplate.process('reminders.tt2', this.templateVars()))
            .dialog({
                height: 425,
                width: 550,
                modal: true
            });

        this.$dialog.find('a').blur();

        // disable all forms
        this.$dialog.find('form').submit(function() { return false });

        // Telephone fields
        this.$dialog.find('.phone').mask('999-999-9999');

        // Custom time picker
        this.$dialog.find('.simpleOffset').change(function() {
            if ($(this).val() == "custom") {
                $(this).hide();
                $(this).siblings('.customOffset').show();
            }
            else {
                $(this).siblings('.customOffset').val($(this).val());
            }
        })

        this.showPage('choose_method');
    },

    showPage: function(name) {
        var self = this;
        var opts = self.wizard()[name] || {};

        self.$dialog.find('.globalError').remove();

        // Hide other pages
        self.$dialog.find('.wizard .page').hide();

        // Show the current page
        var $cur = self.$dialog.find('#'+name).show();
        if (opts.focus) $cur.find(opts.focus).focus();
        if (opts.validate) $cur.find('form').validate(opts.validate);
        
        // Update buttons
        self.$dialog.dialog('option', 'buttons', self.buttons(opts, $cur));
    },

    buttons: function(opts, $cur) {
        var self = this;
        var buttons = [];
        if (opts.next) {
            buttons.push({
                className: 'next',
                text: 'Next',
                click: function() {
                    if ($cur.find('form').valid()) opts.next($cur);
                }
            });
        }
        if (opts.submit) {
            buttons.push({
                className: 'submit',
                text: 'Submit',
                click: function() {
                    $cur.find('.globalError').remove();
                    if ($cur.find('form').valid()) opts.submit($cur);
                }
            });
        }
        if (opts.back) {
            buttons.push({
                className: 'back',
                text: 'Back',
                click: function() {
                    opts.back($cur);
                }
            });
        }
        buttons.push({
            className: 'close',
            text: (opts.next || opts.submit) ? 'Cancel' : 'Close',
            click: function() {
                self.$dialog.dialog('close');
            }
        });
        return buttons;
    },

    addReminder: function (opts) {
        var data = {
            offset: opts.offset,
            email: opts.email,
            name: "reminder" + (new Date).getTime(),
            target: opts.target
        };
        if (opts.payment_period) data.payment_period = opts.payment_period;
        $.ajax({
            type: 'POST',
            url: '/zones/' + opts.zone + '/reminders',
            data: $.toJSON(data, true),
            error: function(xhr, textStatus, errorThrown) {
                var error = xhr.responseText;
                if (error.match(/^</)) error = errorThrown;
                $('#loading').replaceWith(
                    Jemplate.process('error', { error: error })
                );
            },
            success: opts.success
        });
    }
};

})(jQuery);
