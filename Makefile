# Makefile

.PHONY: all
all: deps build

JPM_OPTS += --cflags='-I/usr/local/include'
JPM_OPTS +=--lflags='-L/usr/local/lib'
JPM_OPTS += --local

.PHONY: deps
deps:
	jpm deps ${JPM_OPTS}

.PHONY: build
build:
	jpm build ${JPM_OPTS}

.PHONY: clean
clean:
	rm -rf build jpm_tree
