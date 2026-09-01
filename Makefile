CONFIG  ?= release
APP     := Volumix.app
BINDIR   = $(shell swift build -c $(CONFIG) --show-bin-path)

# Ad-hoc signing. TCC permission follows signing identity and may reset after a rebuild.
# For distribution, use `SIGN_ID="Developer ID Application: ..." make app`.
SIGN_ID ?= -

.PHONY: app run debug stop spike clean

# Removing the bundle while it runs can break LaunchServices (-609), and two instances can race
# for the same taps. Stop the existing process and wait for it to exit before packaging.
stop:
	@pkill -x Volumix 2>/dev/null || true
	@while pgrep -x Volumix >/dev/null 2>&1; do sleep 0.1; done

app: stop
	swift build -c $(CONFIG) --product Volumix
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINDIR)/Volumix $(APP)/Contents/MacOS/Volumix
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	@sign_output=$$(codesign --force --options runtime --sign "$(SIGN_ID)" $(APP) 2>&1) || { \
		printf '%s\n' "$$sign_output" >&2; \
		exit 1; \
	}
	@echo "→ $(APP)"

run: app
	open $(APP)

# Inspect audio graph setup in the terminal: taps, engines, buffer geometry, and levels.
debug: app
	VOLUMIX_DEBUG=1 $(APP)/Contents/MacOS/Volumix

# Phase 0 measurement tool: make spike ARGS="Spotify 0.3 15"
spike:
	@swift build -c debug --product spike >/dev/null
	@$(shell swift build -c debug --show-bin-path)/spike $(ARGS)

clean:
	rm -rf .build $(APP)
