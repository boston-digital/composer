PHP := php -dmemory_limit=-1
SATIS := vendor/bin/satis
COMPOSER := $(shell which composer.phar 2>/dev/null || which composer 2>/dev/null)

all: dist/packages.json

clean:
	rm -rf dist

dist/.git: clean
	git clone git@github.com:boston-digital/composer.git dist -b gh-pages --depth=1

dist/packages.json: dist/.git $(SATIS) Makefile satis.json
	$(PHP) $(SATIS) build satis.json dist

$(SATIS): composer.lock
	$(PHP) $(COMPOSER) install
	touch $@