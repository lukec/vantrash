INSTALL_DIR=/var/www/vantrash
SOURCE_FILES=static/*

release: $(SOURCE_files)
	cp -R $(SOURCE_FILES) $(INSTALL_DIR)
