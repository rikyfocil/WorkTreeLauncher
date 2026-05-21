APP_NAME    = WorktreeLauncher
BINARY      = .build/release/$(APP_NAME)
APP_BUNDLE  = $(APP_NAME).app
CONTENTS    = $(APP_BUNDLE)/Contents
INSTALL_DIR = $(HOME)/Applications
CLI_BIN     = $(HOME)/.local/bin/wl

.PHONY: build app install install-cli clean

build:
	swift build -c release 2>&1

app: build
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BINARY) $(CONTENTS)/MacOS/
	cp Info.plist $(CONTENTS)/
	cp AppIcon.icns $(CONTENTS)/Resources/
	codesign --sign - --force $(APP_BUNDLE)
	@echo "✓ Built $(APP_BUNDLE)"

install: app
	mkdir -p $(INSTALL_DIR)
	cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "✓ Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "  Run 'make install-cli' to install the wl command"

install-cli:
	mkdir -p $(HOME)/.local/bin
	printf '#!/bin/sh\nopen "worktree-launcher://$${1:-$$(pwd)}"\n' > $(CLI_BIN)
	chmod +x $(CLI_BIN)
	@echo "✓ Installed wl → $(CLI_BIN)"
	@echo "  Usage: wl          — open current folder in WorktreeLauncher"
	@echo "         wl /some/repo — open a specific repo"
	@echo "  Make sure ~/.local/bin is in your PATH"

clean:
	swift package clean
