.PHONY: ghostty check-ghostty format lint install

SOURCES := Stanok StanokKit/Sources StanokKit/Terminal StanokKit/Agents StanokTests

# Xcode's script sandbox denies mise shims (they read mise.toml), so bypass PATH.
SWIFTFORMAT := $(firstword $(wildcard /opt/homebrew/bin/swiftformat /usr/local/bin/swiftformat) swiftformat)
SWIFTLINT := $(firstword $(wildcard /opt/homebrew/bin/swiftlint /usr/local/bin/swiftlint) swiftlint)

ghostty:
	./scripts/build-ghostty.sh

check-ghostty:
	@if [ ! -e StanokKit/GhosttyKit.xcframework ]; then \
		echo "error: StanokKit/GhosttyKit.xcframework is missing or its symlink is broken — сначала: make ghostty"; \
		exit 1; \
	fi
	@echo "StanokKit/GhosttyKit.xcframework resolves ok"

format:
	@$(SWIFTFORMAT) $(SOURCES) --quiet
	@./scripts/fix-type-blank-lines.py $$(find $(SOURCES) -name '*.swift') >/dev/null
	@./scripts/fix-property-spacing.py $$(find $(SOURCES) -name '*.swift') >/dev/null
	@./scripts/fix-declaration-order.py $$(find $(SOURCES) -name '*.swift') >/dev/null

lint:
	@$(SWIFTLINT) lint --quiet
	@./scripts/check-file-groups.py
	@./scripts/check-declaration-order.py

install:
	xcodebuild -project Stanok.xcodeproj -scheme Stanok -configuration Release \
		-destination 'platform=macOS' -derivedDataPath .build/release build
	rm -rf /Applications/Stanok.app
	cp -R .build/release/Build/Products/Release/Stanok.app /Applications/
	@echo "Stanok.app обновлён в /Applications"
