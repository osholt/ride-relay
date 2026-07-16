FLUTTER ?= flutter
MOBILE_DIR := apps/mobile

.PHONY: setup format check test android ios

setup:
	cd $(MOBILE_DIR) && $(FLUTTER) pub get

format:
	cd $(MOBILE_DIR) && dart format lib test

check:
	cd $(MOBILE_DIR) && $(FLUTTER) analyze
	cd $(MOBILE_DIR) && $(FLUTTER) test

test:
	cd $(MOBILE_DIR) && $(FLUTTER) test --coverage

android:
	cd $(MOBILE_DIR) && $(FLUTTER) build apk --debug

ios:
	cd $(MOBILE_DIR) && $(FLUTTER) build ios --debug --no-codesign
