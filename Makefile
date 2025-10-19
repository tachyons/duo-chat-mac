.PHONY: all build build-release test clean install run

PROJECT = duo-chat.xcodeproj
SCHEME = duo-chat
APP_NAME = duo-chat
TEST_SCHEME_UNIT = duo-chatTests
TEST_SCHEME_UI = duo-chatUITests
BUILD_DIR = build
INSTALL_DIR = /Applications

# Default target
all: build

# Build debug version
build:
	@echo "Building $(SCHEME) project (Debug)..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE=""

# Build release version
build-release:
	@echo "Building $(SCHEME) project (Release)..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath DerivedData \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE=""
# Run the application (after building)
run: build
	@echo "Running $(APP_NAME)..."
	open $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# Run tests
test:
	@echo "Running unit tests for $(TEST_SCHEME_UNIT)..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(TEST_SCHEME_UNIT) \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE=""

	@echo "Running UI tests for $(TEST_SCHEME_UI)..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(TEST_SCHEME_UI) \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE=""
# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf DerivedData
	rm -f $(APP_NAME).zip $(APP_NAME).dmg checksums.txt

# Install the release version of the application
install: build-release
	@echo "Installing $(APP_NAME).app to $(INSTALL_DIR)..."
	cp -R $(BUILD_DIR)/$(APP_NAME).app $(INSTALL_DIR)
	@echo "Installation complete. You may need to restart your Dock or log out/in to see the app in Launchpad."
