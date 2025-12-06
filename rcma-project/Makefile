CURRENT_DIR := $(shell pwd)

all: build
	cp $(CURRENT_DIR)/target/release/rcma $(CURRENT_DIR)/../rcma

build:
	cargo build --release
