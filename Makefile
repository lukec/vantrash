INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
DATAFILE=trash-zone-times.yaml
TEMPLATES=html
EXEC=bin/*
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'

JS_DIR=static/javascript
JS_TARGET=$(JS_DIR)/vantrash-compiled.js
JS_MINI=$(JS_DIR)/vantrash-compiled-mini.js
JS_FILES=\
	 $(JS_DIR)/jquery-latest.js \
	 $(JS_DIR)/egeoxml.js \
	 $(JS_DIR)/epoly.js \
	 $(JS_DIR)/cal.js \
	 $(JS_DIR)/vantrash.js

ALL_TEMPLATES=$(wildcard template/*.tt2)
OTHER_TEMPLATES=
TEMPLATES=$(filter-out $(OTHER_TEMPLATES),$(ALL_TEMPLATES))
HTML=$(TEMPLATES:template/%.tt2=static/%.html)

all: $(JS_MINI) $(HTML)

clean:
	rm -f $(JS_MINI) $(JS_TARGET) $(HTML)

.SUFFIXES: .js -mini.js

.js-mini.js:
	$(MINIFY) $< > $@

$(JS_TARGET): $(JS_FILES) Makefile
	rm -f $@;
	for js in $(JS_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

static/%.html: $(OTHER_TEMPLATES) template/%.tt2
	$(PERL) bin/process-template ${@:static/%.html=%}
	@grep $@ .gitignore >/dev/null || echo $@ >> .gitignore && :

install: $(JS_MINI) $(SOURCE_files) $(LIB) $(DATAFILE) $(TEMPLATES) $(EXEC)
	sudo cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	sudo cp -R $(LIB) $(DATAFILE) $(TEMPLATES) $(INSTALL_DIR)
	sudo cp $(EXEC) $(INSTALL_DIR)/bin
	sudo /etc/init.d/apache2 restart

