INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
DATAFILE=trash-zone-times.yaml
TEMPLATES=html

release: $(SOURCE_files) $(LIB) $(DATAFILE) $(TEMPLATES)
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(DATAFILE) $(TEMPLATES) $(INSTALL_DIR)
	sudo /etc/init.d/apache2 restart

