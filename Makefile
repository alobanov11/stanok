.PHONY: ghostty check-ghostty

ghostty:
	./scripts/build-ghostty.sh

check-ghostty:
	@if [ ! -e StanokKit/GhosttyKit.xcframework ]; then \
		echo "error: StanokKit/GhosttyKit.xcframework is missing or its symlink is broken — сначала: make ghostty"; \
		exit 1; \
	fi
	@echo "StanokKit/GhosttyKit.xcframework resolves ok"
