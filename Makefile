.PHONY: all build build-release test clean install run help

PROJECT = duo-chat.xcodeproj
SCHEME = duo-chat
APP_NAME = duo-chat
TEST_SCHEME_UNIT = duo-chatTests
TEST_SCHEME_UI = duo-chatUITests
BUILD_DIR = build
INSTALL_DIR = /Applications
VERSION = 0.1.0

# Default target
all: build

# Help target
help:
	@echo "Available targets:"
	@echo "  make build          - Build debug version"
	@echo "  make build-release  - Build release version with packages"
	@echo "  make test           - Run unit and UI tests"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make install        - Install release version to /Applications"
	@echo "  make run            - Build and run debug version"
	@echo "  make help           - Show this help message"

# Build debug version
build:
	@echo "Building $(SCHEME) project (Debug)..."
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE="" || \
		(echo "Build failed"; exit 1)

# Build release version
build-release:
	@echo "Building $(SCHEME) project (Release) and creating archives..."
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE="" || \
		(echo "Build failed"; exit 1)
	@echo "Copying built app..."
	@if [ -d "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" ]; then \
		cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(BUILD_DIR)/$(APP_NAME).app"; \
	else \
		echo "Error: Built app not found at expected location"; \
		exit 1; \
	fi
	@echo "Creating distribution packages..."
	@cd $(BUILD_DIR) && \
		zip -r "$(APP_NAME).zip" "$(APP_NAME).app" && \
		hdiutil create -volname "$(APP_NAME)" -srcfolder "$(APP_NAME).app" -ov -format UDZO "$(APP_NAME).dmg" && \
		tar -czf "duo-chat-macos-v$(VERSION).tar.gz" "$(APP_NAME).app" && \
		shasum -a 256 "$(APP_NAME).zip" "$(APP_NAME).dmg" "duo-chat-macos-v$(VERSION).tar.gz" > checksums.txt
	@echo "Build complete! Packages created in $(BUILD_DIR)/"
	@echo "  - $(APP_NAME).zip"
	@echo "  - $(APP_NAME).dmg"
	@echo "  - duo-chat-macos-v$(VERSION).tar.gz"
	@echo "  - checksums.txt"

# Run the application (after building)
run: build
	@echo "Running $(APP_NAME)..."
	@if [ -d "$(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app" ]; then \
		open "$(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app"; \
	else \
		echo "Error: App not found at $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app"; \
		echo "Build may have failed or app is in a different location."; \
		exit 1; \
	fi

# Run tests
test:
	@echo "Running unit tests for $(TEST_SCHEME_UNIT)..."
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(TEST_SCHEME_UNIT) \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE="" || \
		(echo "Unit tests failed"; exit 1)
	@echo "Running UI tests for $(TEST_SCHEME_UI)..."
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(TEST_SCHEME_UI) \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE="" || \
		(echo "UI tests failed"; exit 1)
	@echo "All tests passed successfully!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete!"

# Install the release version of the application
install: build-release
	@echo "Installing $(APP_NAME).app to $(INSTALL_DIR)..."
	@if [ -d "$(BUILD_DIR)/$(APP_NAME).app" ]; then \
		sudo cp -R "$(BUILD_DIR)/$(APP_NAME).app" "$(INSTALL_DIR)"; \
		echo "Installation complete!"; \
		echo "You may need to restart your Dock or log out/in to see the app in Launchpad."; \
	else \
		echo "Error: $(APP_NAME).app not found in $(BUILD_DIR)/"; \
		exit 1; \
	fi
