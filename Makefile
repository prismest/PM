.PHONY: all build test run clean

all: build

build:
	./build_app.sh

test:
	python3 -m unittest discover -s tests -p "test_*.py" -v

run:
	open Waan.app

clean:
	rm -rf .build Waan.app

