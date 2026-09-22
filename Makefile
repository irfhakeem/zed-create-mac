PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

SWIFT_SOURCES = src/DirectoryScanner.swift \
                src/FuzzyMatcher.swift \
                src/FileCreator.swift \
                src/ModalWindow.swift \
                src/main.swift

all: zed-create

zed-create: $(SWIFT_SOURCES)
	@echo "==> Compiling native macOS GUI modal (zed-create)..."
	swiftc -O $(SWIFT_SOURCES) -o zed-create

test:
	@echo "==> Running Swift unit tests..."
	swiftc -O src/DirectoryScanner.swift src/FuzzyMatcher.swift src/FileCreator.swift tests/TestRunner.swift -o tests/run_tests
	./tests/run_tests
	@rm -f tests/run_tests

install: all
	@./install.sh

clean:
	rm -f zed-create tests/run_tests

.PHONY: all test install clean
