INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
TEMPLATE_DIR=template
EXEC=bin/*
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
MINIFY=cat

JS_DIR=static/javascript
JS_TARGET=$(JS_DIR)/vantrash-compiled.js
JS_MINI=$(JS_DIR)/vantrash-compiled-mini.js
JS_FILES=\
	 $(JS_DIR)/jquery-latest.js \
	 $(JS_DIR)/jquery-json-1.3.js \
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

WIKI_PAGES=about_us faq
WIKI_HTMLS=$(WIKI_PAGES:%=template/%.html)
CRONJOB=etc/cron.d/vantrash

TESTS=$(wildcard t/*.t)
WIKITESTS=$(wildcard t/wikitests/*.t)

all: $(JS_MINI) $(JS_MAP_TARGET) $(JS_MAP_MINI) $(WIKI_HTMLS)

clean:
	rm -f $(JS_MINI) $(JS_TARGET) $(JS_MAP_TARGET) $(JS_MAP_MINI) $(WIKI_HTMLS)

.SUFFIXES: .js -mini.js

.js-mini.js:
	$(MINIFY) $< > $@

$(WIKI_HTMLS): Makefile
	rm -f $@;
	bin/fetch-from-wiki $(@:template/%.html=%) > $@
	@grep $@ .gitignore >/dev/null || echo $@ >> .gitignore && :

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

$(INSTALL_DIR)/%:
	mkdir $@

install: $(INSTALL_DIR)/* $(JS_MINI) $(SOURCE_files) $(LIB) \
    	 $(TEMPLATES) $(EXEC) $(TEMPLATE_DIR) $(CRONJOB)
	rm -rf $(INSTALL_DIR)/root/*
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(TEMPLATE_DIR) $(INSTALL_DIR)
	rm -f $(INSTALL_DIR)/root/*.html
	cp data/vantrash.dump $(INSTALL_DIR)/data
	cp $(EXEC) $(INSTALL_DIR)/bin
	cp -f etc/cron.d/vantrash /etc/cron.d/vantrash
	cp -f etc/apache2/sites-available/000-default /etc/apache2/sites-available
	ln -sf /etc/apache2/sites-available/000-default /etc/apache2/sites-enabled/000-default
	cp -f etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-available
	ln -sf /etc/nginx/sites-available/vantrash.ca /etc/nginx/sites-enabled/vantrash.ca
	cd $(INSTALL_DIR) && bin/setup-env
	chown www-data:www-data $(INSTALL_DIR)/data/vantrash.db
	/etc/init.d/apache2 restart
	/etc/init.d/nginx reload

test: $(TESTS)
	prv $(TESTS)

wikitest: $(WIKITESTS)
	prove $(WIKITESTS)
	
