.PHONY: ghostty check-ghostty install

ghostty:
	./scripts/build-ghostty.sh

check-ghostty:
	@if [ ! -e StanokKit/GhosttyKit.xcframework ]; then \
		echo "error: StanokKit/GhosttyKit.xcframework is missing or its symlink is broken — сначала: make ghostty"; \
		exit 1; \
	fi
	@echo "StanokKit/GhosttyKit.xcframework resolves ok"

install:
	xcodebuild -project Stanok.xcodeproj -scheme Stanok -configuration Release \
		-destination 'platform=macOS' -derivedDataPath .build/release build
	rm -rf /Applications/Stanok.app
	cp -R .build/release/Build/Products/Release/Stanok.app /Applications/
	@echo "Stanok.app обновлён в /Applications"
