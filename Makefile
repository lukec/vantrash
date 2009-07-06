INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
CGI=bin/vantrash-cgi.pl
LIB=lib
DATAFILE=trash-zone-times.yaml
TEMPLATES=html

release: $(SOURCE_files) $(CGI) $(LIB) $(DATAFILE) $(TEMPLATES)
	cp -R $(SOURCE_FILES) $(LIB) $(DATAFILE) $(TEMPLATES) $(INSTALL_DIR)
	sudo /etc/init.d/apache2 restart

