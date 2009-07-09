INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*
LIB=lib
DATAFILE=trash-zone-times.yaml
TEMPLATES=html
EXEC=bin/*

release: $(SOURCE_files) $(LIB) $(DATAFILE) $(TEMPLATES) $(EXEC)
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)/root
	cp -R $(LIB) $(DATAFILE) $(TEMPLATES) $(INSTALL_DIR)
	cp $(EXEC) $(INSTALL_DIR)/bin
	sudo /etc/init.d/apache2 restart

