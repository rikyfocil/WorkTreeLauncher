APP_NAME    = WorktreeLauncher
BINARY      = .build/release/$(APP_NAME)
APP_BUNDLE  = $(APP_NAME).app
CONTENTS    = $(APP_BUNDLE)/Contents
INSTALL_DIR = $(HOME)/Applications

.PHONY: build app install clean

build:
	swift build -c release 2>&1

app: build
	mkdir -p $(CONTENTS)/MacOS
	cp $(BINARY) $(CONTENTS)/MacOS/
	cp Info.plist $(CONTENTS)/
	codesign --sign - --force $(APP_BUNDLE)
	@echo "✓ Built $(APP_BUNDLE)"

install: app
	mkdir -p $(INSTALL_DIR)
	cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "✓ Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo ""
	@echo "Add this shell function to open any repo's worktrees:"
	@echo "  wl() { open -a WorktreeLauncher --args \"\$${1:-\$$(pwd)}\" }"

clean:
	swift package clean
