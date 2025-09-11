# ==============================================================================
# Project Variables
# ==============================================================================

# The name of the executable
TARGET := json-to-sqlite

# Get the version from the latest git tag. Fallback to v0.0.0-dev if no tags.
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0-dev")

# Go build flags
# -s -w: to make smaller binaries
# -X main.Version=$(VERSION): to embed the version string
LDFLAGS := -ldflags="-s -w -X main.Version=$(VERSION)"

# Build output directory
BUILD_DIR := ./bin


# ==============================================================================
# Main Targets
# ==============================================================================

.PHONY: all
all: build

.PHONY: build
build: build-linux build-windows build-mac
	@echo "All platforms built successfully."

.PHONY: package
package: build
	@echo "Packaging for distribution..."
	$(MAKE) package-linux
	$(MAKE) package-windows
	$(MAKE) package-mac
	@echo "All packages created in $(BUILD_DIR)"

.PHONY: clean
clean:
	@echo "Cleaning up build artifacts..."
	@rm -rf $(BUILD_DIR)

# ==============================================================================
# Platform-Specific Build Targets
# ==============================================================================

.PHONY: build-linux
build-linux:
	@echo "Building for Linux (amd64)..."
	@mkdir -p $(BUILD_DIR)/linux-amd64
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/linux-amd64/$(TARGET) .

.PHONY: build-windows
build-windows:
	@echo "Building for Windows (amd64)..."
	@mkdir -p $(BUILD_DIR)/windows-amd64
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/windows-amd64/$(TARGET).exe .

# Note: Building a universal binary requires running on macOS with Xcode tools installed.
.PHONY: build-mac
build-mac:
	@echo "Building for macOS (Universal)..."
	@mkdir -p $(BUILD_DIR)/darwin-universal
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(TARGET)-amd64 .
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(TARGET)-arm64 .
	@lipo -create -output $(BUILD_DIR)/darwin-universal/$(TARGET) $(BUILD_DIR)/$(TARGET)-amd64 $(BUILD_DIR)/$(TARGET)-arm64
	@rm $(BUILD_DIR)/$(TARGET)-amd64 $(BUILD_DIR)/$(TARGET)-arm64


# ==============================================================================
# Packaging Targets
# ==============================================================================

.PHONY: package-linux
package-linux:
	@cd $(BUILD_DIR)/linux-amd64 && tar -czf ../$(TARGET)-$(VERSION)-linux-amd64.tar.gz $(TARGET)

.PHONY: package-windows
package-windows:
	@cd $(BUILD_DIR)/windows-amd64 && zip -r ../$(TARGET)-$(VERSION)-windows-amd64.zip $(TARGET).exe

.PHONY: package-mac
package-mac:
	@cd $(BUILD_DIR)/darwin-universal && tar -czf ../$(TARGET)-$(VERSION)-darwin-universal.tar.gz $(TARGET)
