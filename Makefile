INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
DATAFILE=data/trash-zone-times.yaml
TEMPLATE_DIR=template
EXEC=bin/*
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
MINIFY=cat

JS_DIR=static/javascript
JS_TARGET=$(JS_DIR)/vantrash-compiled.js
JS_MINI=$(JS_DIR)/vantrash-compiled-mini.js
JS_FILES=\
	 $(JS_DIR)/jquery-latest.js \
	 $(JS_DIR)/jquery.lightbox.js \
	 $(JS_DIR)/cal.js \
	 $(JS_DIR)/reminders.js \
	 $(JS_DIR)/wizard.js \

JS_MAP_TARGET=$(JS_DIR)/vantrash-map-compiled.js
JS_MAP_MINI=$(JS_DIR)/vantrash-map-compiled-mini.js
JS_MAP_FILES=\
	 $(JS_DIR)/egeoxml.js \
	 $(JS_DIR)/epoly.js \
	 $(JS_DIR)/map.js \

ALL_TEMPLATES=$(wildcard template/*.tt2)
OTHER_TEMPLATES=template/wrapper.tt2
TEMPLATES=$(filter-out $(OTHER_TEMPLATES),$(ALL_TEMPLATES))
LIGHTBOXES=template/donate.tt2 template/new_reminder.tt2
HTML=$(TEMPLATES:template/%.tt2=static/%.html)
LIGHTBOX_HTML=$(LIGHTBOXES:template/%.tt2=static/%-lightbox.html)
TESTS=$(wildcard t/*.t)
WIKITESTS=$(wildcard t/wikitests/*.t)

all: $(JS_MINI) $(JS_MAP_TARGET) $(JS_MAP_MINI) $(HTML) $(LIGHTBOX_HTML)

clean:
	rm -f $(JS_MINI) $(JS_TARGET) $(JS_MAP_TARGET) $(JS_MAP_MINI) $(HTML) $(LIGHTBOX_HTML)

.SUFFIXES: .js -mini.js

.js-mini.js:
	$(MINIFY) $< > $@

$(JS_TARGET): $(JS_FILES) Makefile
	rm -f $@;
	for js in $(JS_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(JS_MAP_TARGET): $(JS_MAP_FILES) Makefile
	rm -f $@;
	for js in $(JS_MAP_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

static/%-lightbox.html: $(OTHER_TEMPLATES) template/%.tt2
	$(PERL) bin/process-template --lightbox $(@:static/%-lightbox.html=%) > $@
	@grep $@ .gitignore >/dev/null || echo $@ >> .gitignore && :

static/%.html: $(OTHER_TEMPLATES) template/%.tt2
	$(PERL) bin/process-template $(@:static/%.html=%) > $@
	@grep $@ .gitignore >/dev/null || echo $@ >> .gitignore && :

install: $(JS_MINI) $(SOURCE_files) $(LIB) $(DATAFILE) $(TEMPLATES) $(EXEC) $(TEMPLATE_DIR)
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(TEMPLATE_DIR) $(INSTALL_DIR)
	cp $(DATAFILE) $(INSTALL_DIR)/data
	cp $(EXEC) $(INSTALL_DIR)/bin
	cp -f etc/apache2/sites-available/000-default /etc/apache2/sites-available
	ln -sf /etc/apache2/sites-available/000-default /etc/apache2/sites-enabled/000-default
	cp -f etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-available
	ln -sf /etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-enabled/vantrash.ca
	/etc/init.d/apache2 restart
	/etc/init.d/nginx reload

test: $(TESTS) $(WIKITESTS)
	prv $(TESTS)
	prove $(WIKITESTS)
	
