# Makefile for QuickRecorder
# This Makefile provides commands to build the app and create a DMG

# Variables
PROJECT_NAME := QuickRecorder
PROJECT_FILE := $(PROJECT_NAME).xcodeproj
SCHEME := $(PROJECT_NAME)
CONFIGURATION := Release
BUILD_DIR := build
APP_NAME := $(PROJECT_NAME).app
DMG_NAME := $(PROJECT_NAME).dmg

# Dynamically find the derived data path
DERIVED_DATA_DIR := $(shell find ~/Library/Developer/Xcode/DerivedData -name "$(PROJECT_NAME)-*" -type d -depth 1 | head -n 1)
BUILT_APP_PATH := $(DERIVED_DATA_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME)

# Default target
.PHONY: all
all: build dmg

# Clean build directory
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete."

# Build the app
.PHONY: build
build:
	@echo "Building $(PROJECT_NAME) app..."
	@xcodebuild -project $(PROJECT_FILE) -scheme $(SCHEME) -configuration $(CONFIGURATION) build
	@echo "Build complete."

# Create the DMG
.PHONY: dmg
dmg: build
	@echo "Creating DMG for $(PROJECT_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@echo "Copying app from: $(BUILT_APP_PATH)"
	@cp -r "$(BUILT_APP_PATH)" $(BUILD_DIR)/
	@hdiutil create -volname "$(PROJECT_NAME)" -srcfolder $(BUILD_DIR) -ov -format UDZO $(BUILD_DIR)/$(DMG_NAME)
	@echo "DMG created at: $(BUILD_DIR)/$(DMG_NAME)"

# Show help
.PHONY: help
help:
	@echo "QuickRecorder Build System"
	@echo "-------------------------"
	@echo "Available targets:"
	@echo "  all    - Build the app and create a DMG (default)"
	@echo "  build  - Build the app only"
	@echo "  dmg    - Create a DMG from the built app"
	@echo "  clean  - Clean the build directory"
	@echo "  help   - Show this help message"