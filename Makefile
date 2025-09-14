.PHONY: gen build test clean

gen:
	@echo "Generating Xcode project with XcodeGen..."
	@xcodegen generate

build:
	@echo "Building QuietMic..."
	@xcodebuild -scheme QuietMic -destination 'platform=iOS Simulator,name=iPhone 16' build

test:
	@echo "Running tests..."
	@xcodebuild -scheme QuietMic -destination 'platform=iOS Simulator,name=iPhone 16' test

clean:
	@echo "Cleaning project..."
	@rm -rf QuietMic.xcodeproj DerivedData
	@xcodebuild clean -scheme QuietMic || true

help:
	@echo "Available commands:"
	@echo "  gen   - Generate Xcode project from project.yml"
	@echo "  build - Build the project"
	@echo "  test  - Run all tests"
	@echo "  clean - Clean build artifacts and generated project"