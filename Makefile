default: all

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

LS = node_modules/livescript
LSC = node_modules/.bin/lsc
MOCHA = node_modules/.bin/mocha
MOCHA2 = node_modules/.bin/_mocha
ISTANBUL = node_modules/.bin/istanbul

lib:
	mkdir -p lib/

lib/%.js: src/%.ls lib
	$(LSC) --compile --output lib "$<"

.PHONY: build test coverage dev-install loc clean

all: build

build: $(LIB)

test: build
	$(MOCHA) --reporter dot --ui tdd --compilers ls:$(LS)

coverage: build
	$(ISTANBUL) cover $(MOCHA2) -- --reporter dot --ui tdd --compilers ls:$(LS)

dev-install:
	npm install .

loc:
	wc -l $(SRC)

clean:
	rm -rf lib
	rm -rf coverage
