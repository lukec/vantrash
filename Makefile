INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
TEMPLATE_DIR=template
EXEC=bin/*
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
#MINIFY=cat

JS_DIR=static/javascript

JEMPLATE=$(JS_DIR)/Jemplate.js
JEMPLATES=$(wildcard $(JS_DIR)/template/*.tt2)

VANTRASH=$(JS_DIR)/vantrash.js
VANTRASH_GZ=$(JS_DIR)/vantrash.js.gz
VANTRASH_MINIFIED=$(JS_DIR)/vantrash-mini.js
VANTRASH_FILES=\
	 $(JS_DIR)/libs/jquery-1.4.2.min.js \
	 $(JS_DIR)/libs/jquery-ui-1.8.6.custom.min.js \
	 $(JS_DIR)/libs/jquery-json-1.3.js \
	 $(JS_DIR)/libs/jquery-maskedinput-1.2.2.min.js \
	 $(JS_DIR)/libs/jquery.validate.js \
	 $(JS_DIR)/vantrash/reminders.js \
	 $(JEMPLATE) \

VANTRASH_MAP=$(JS_DIR)/vantrash-map.js
VANTRASH_MAP_GZ=$(JS_DIR)/vantrash-map.js.gz
VANTRASH_MAP_MINIFIED=$(JS_DIR)/vantrash-map-mini.js
VANTRASH_MAP_FILES=\
	 $(JS_DIR)/libs/egeoxml.js \
	 $(JS_DIR)/libs/epoly.js \
	 $(JS_DIR)/vantrash/map.js \

VANTRASH_MOBILE=$(JS_DIR)/vantrash-mobile.js
VANTRASH_MOBILE_GZ=$(JS_DIR)/vantrash-mobile.js.gz
VANTRASH_MOBILE_MINIFIED=$(JS_DIR)/vantrash-mobile-mini.js
VANTRASH_MOBILE_FILES=\
	 $(JS_DIR)/libs/jquery-1.4.2.min.js \
	 $(JS_DIR)/libs/jquery-ui-1.8.6.custom.min.js \
	 $(JS_DIR)/libs/jquery-json-1.3.js \
	 $(JS_DIR)/libs/gears_init.js \
	 $(JS_DIR)/vantrash/cal.js \
	 $(JS_DIR)/vantrash/map.js \
	 $(JS_DIR)/vantrash/reminders.js \

CRONJOB=etc/cron.d/vantrash
PSGI=production.psgi

TESTS=$(wildcard t/*.t)
WIKITESTS=$(wildcard t/wikitests/*.t)

all: \
    $(VANTRASH_GZ) $(VANTRASH_MINIFIED) \
    $(VANTRASH_MOBILE_GZ) $(VANTRASH_MOBILE_MINIFIED) \
    $(VANTRASH_MAP_GZ) $(VANTRASH_MAP_MINIFIED) \

clean:
	rm -f \
	    $(JEMPLATE) \
	    $(VANTRASH) $(VANTRASH_MINIFIED) $(VANTRASH_GZ) \
	    $(VANTRASH_MAP) $(VANTRASH_MAP_MINIFIED) $(VANTRASH_MAP_GZ) \
	    $(VANTRASH_MOBILE) $(VANTRASH_MOBILE_MINIFIED) $(VANTRASH_MOBILE_GZ) \

.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

$(JEMPLATE): $(JEMPLATES)
	jemplate --runtime=jquery > $@
	echo ';' >> $@
	jemplate --compile $(JEMPLATES) >> $@
	echo ';' >> $@

$(VANTRASH): $(VANTRASH_FILES) Makefile
	rm -f $@;
	for js in $(VANTRASH_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(VANTRASH_MOBILE): $(VANTRASH_MOBILE_FILES) Makefile
	rm -f $@;
	for js in $(VANTRASH_MOBILE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(VANTRASH_MAP): $(VANTRASH_MAP_FILES) Makefile
	rm -f $@;
	for js in $(VANTRASH_MAP_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

-mini.js.js.gz:
	gzip -c $< > $@

$(INSTALL_DIR)/%:
	mkdir $(INSTALL_DIR)
	mkdir $(INSTALL_DIR)/root
	mkdir $(INSTALL_DIR)/bin
	mkdir $(INSTALL_DIR)/etc
	mkdir $(INSTALL_DIR)/data
	chown -R vantrash:www-data $(INSTALL_DIR)


install: $(INSTALL_DIR)/* $(JS_MINI) $(JS_MAP_MINI) $(SOURCE_FILES) $(LIB) \
	$(TEMPLATES) $(EXEC) $(TEMPLATE_DIR) $(CRONJOB) $(PSGI)
	rm -rf $(INSTALL_DIR)/root/css
	rm -rf $(INSTALL_DIR)/root/images
	rm -rf $(INSTALL_DIR)/root/javascript
	if [ ! -d $(INSTALL_DIR)/root/reports ]; then mkdir $(INSTALL_DIR)/root/reports; fi
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(TEMPLATE_DIR) $(INSTALL_DIR)
	rm -f $(INSTALL_DIR)/root/*.html
	cp $(PSGI) $(INSTALL_DIR)
	cp data/vantrash.dump $(INSTALL_DIR)/data
	cp $(EXEC) $(INSTALL_DIR)/bin
	cp -f etc/cron.d/vantrash /etc/cron.d/vantrash
	cp -f etc/areas.yaml $(INSTALL_DIR)/etc/areas.yaml
	svc -d /etc/service/vantrash
	rm -rf $(INSTALL_DIR)/etc/service
	cp -R etc/service $(INSTALL_DIR)/etc/service
	if [ ! -d /etc/service/vantrash ]; then \
	    update-service --add $(INSTALL_DIR)/etc/service/vantrash vantrash; \
	fi
	svc -u /etc/service/vantrash
	cp -f etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-available
	ln -sf /etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-enabled/vantrash.ca
	cd $(INSTALL_DIR) && bin/setup-env
	chown -R vantrash:www-data $(INSTALL_DIR)/data/ $(INSTALL_DIR)/root
	/etc/init.d/nginx reload

test: $(TESTS)
	prv $(TESTS)

wikitest: $(WIKITESTS)
	prove $(WIKITESTS)
	
