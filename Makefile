SCHEME ?= QuietMic
CONFIG ?= Debug
DEST   ?= 'platform=iOS Simulator,name=iPhone 16'

.PHONY: gen build test clean

gen:
	@echo "Generating Xcode project with XcodeGen (cache)…"
	@xcodegen generate --use-cache

build:
	@echo "Building QuietMic..."
	@xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
	  -destination $(DEST) build

test:
	@echo "Running tests..."
	@xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
	  -destination $(DEST) test

clean:
	@echo "Cleaning project..."
	@xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) clean
	# If you still see "modified during build" after big branch/config changes,
	# uncomment the next line to clear this project's DerivedData:
	# rm -rf ~/Library/Developer/Xcode/DerivedData/QuietMic*

help:
	@echo "Available commands:"
	@echo "  gen   - Generate Xcode project from project.yml"
	@echo "  build - Build the project"
	@echo "  test  - Run all tests"
	@echo "  clean - Clean build artifacts and generated project"