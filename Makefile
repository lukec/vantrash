INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
DATAFILE=trash-zone-times.yaml
TEMPLATES=html
EXEC=bin/*
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'

JS=static/vantrash-compiled.js
JS_MINI=static/vantrash-compiled-mini.js
JS_FILES=\
	 static/jquery-latest.js \
	 static/egeoxml.js \
	 static/epoly.js \
	 static/vantrash.js

all: $(JS_MINI)

clean:
	rm -f $(JS_MINI) $(JS)

.SUFFIXES: .js -mini.js

.js-mini.js:
	$(MINIFY) $< > $@

$(JS): $(JS_FILES) Makefile
	rm -f $@;
	for js in $(JS_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

install: $(JS_MINI) $(SOURCE_files) $(LIB) $(DATAFILE) $(TEMPLATES) $(EXEC)
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(DATAFILE) $(TEMPLATES) $(INSTALL_DIR)
	cp $(EXEC) $(INSTALL_DIR)/bin
	sudo /etc/init.d/apache2 restart

install_static: $(JS_MINI) $(SOURCE_FILES)
	sudo cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
