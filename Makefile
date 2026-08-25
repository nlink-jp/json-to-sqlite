BINARY  := json-to-sqlite
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
# Note: capital V — matches `var Version string` in main.go
LDFLAGS := -ldflags '-X main.Version=$(VERSION)'

# Container runtime (podman preferred, docker as fallback)
CONTAINER := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
# Go image used for container builds — must match go.mod toolchain.
GO_IMAGE  := golang:1.26

# macOS Developer ID signing / notarization (see nlink-jp/.github
# CONVENTIONS.md §Code Signing). Defaults match any Developer ID
# Application cert in the keychain and the org-standard notary
# profile. Builds without these fall back to ad-hoc / un-notarized
# with a one-line warning — see scripts/codesign-darwin.sh.
CODESIGN_IDENTITY ?= Developer ID Application
NOTARY_PROFILE    ?= nlink-jp-notary

# darwin ships arm64 only (no amd64, no universal). linux/windows keep their matrix.
PLATFORMS := \
	linux/amd64 \
	linux/arm64 \
	darwin/arm64 \
	windows/amd64

.PHONY: build build-all build-darwin build-linux build-linux-native build-windows \
        test lint check package verify-release clean help

## build: Build for the current platform
build:
	@mkdir -p dist
	go build $(LDFLAGS) -o dist/$(BINARY) .
	@scripts/codesign-darwin.sh dist/$(BINARY) "$(CODESIGN_IDENTITY)"

## build-all: Cross-compile for all target platforms
build-all: build-darwin build-linux build-windows

## build-darwin: Compile darwin/arm64 (macOS host only; arm64-only policy, no Intel)
build-darwin:
	@mkdir -p dist
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-arm64 .
	@scripts/codesign-darwin.sh dist/$(BINARY)-darwin-arm64 "$(CODESIGN_IDENTITY)" "$(BINARY)"

## build-linux: Compile linux/amd64 and linux/arm64 inside a container
# CGO requires a Linux host; run inside a container via podman/docker.
build-linux:
	@if [ -z "$(CONTAINER)" ]; then \
		echo "Error: podman or docker is required for Linux cross-compilation."; \
		echo "Install podman (brew install podman) or run 'make build-linux-native' on a Linux host."; \
		exit 1; \
	fi
	@mkdir -p dist
	@echo "Using container runtime: $(CONTAINER)"
	$(CONTAINER) run --rm \
		-v "$(CURDIR):/workspace:z" \
		-w /workspace \
		$(GO_IMAGE) \
		bash -c "apt-get update -qq && apt-get install -y -q \
			gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
			gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
			&& make build-linux-native"

## build-linux-native: Compile linux/amd64 and linux/arm64 (Linux host only)
build-linux-native:
	@mkdir -p dist
	@echo "Building linux/amd64..."
	@if [ "$$(uname -m)" = "aarch64" ]; then \
		GOOS=linux GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-linux-gnu-gcc \
			go build $(LDFLAGS) -o dist/$(BINARY)-linux-amd64 .; \
	else \
		GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
			go build $(LDFLAGS) -o dist/$(BINARY)-linux-amd64 .; \
	fi
	@echo "Building linux/arm64..."
	@if [ "$$(uname -m)" = "x86_64" ]; then \
		GOOS=linux GOARCH=arm64 CGO_ENABLED=1 CC=aarch64-linux-gnu-gcc \
			go build $(LDFLAGS) -o dist/$(BINARY)-linux-arm64 .; \
	else \
		GOOS=linux GOARCH=arm64 CGO_ENABLED=1 \
			go build $(LDFLAGS) -o dist/$(BINARY)-linux-arm64 .; \
	fi

## build-windows: Compile windows/amd64 inside a container (requires podman or docker)
# Uses the UCRT64 mingw toolchain (matches modern C runtime). Debian ships
# UCRT64 archives without an index, so we ranlib every .a in the toolchain
# before linking. See feedback_cgo_windows_ucrt notes / gem-query Makefile.
build-windows:
	@if [ -z "$(CONTAINER)" ]; then \
		echo "Error: podman or docker is required for Windows cross-compilation."; \
		echo "Install podman (brew install podman)."; \
		exit 1; \
	fi
	@mkdir -p dist
	@echo "Using container runtime: $(CONTAINER)"
	$(CONTAINER) run --rm \
		-v "$(CURDIR):/workspace:z" \
		-w /workspace \
		$(GO_IMAGE) \
		bash -c 'apt-get update -qq && apt-get install -y -q gcc-mingw-w64-ucrt64 g++-mingw-w64-ucrt64 \
			&& find /usr/lib/gcc/x86_64-w64-mingw32ucrt /usr/x86_64-w64-mingw32ucrt -name "*.a" -exec x86_64-w64-mingw32ucrt-ranlib {} + \
			&& GOOS=windows GOARCH=amd64 CGO_ENABLED=1 \
			CC=x86_64-w64-mingw32ucrt-gcc CXX=x86_64-w64-mingw32ucrt-g++ \
			go build -ldflags "-X main.Version=$(VERSION)" -o dist/$(BINARY)-windows-amd64.exe .'

## test: Run the full test suite
test:
	go test -race -cover ./...

## lint: Run golangci-lint
lint:
	golangci-lint run ./...

## check: Run lint + test + build-darwin
check: lint test build-darwin

## package: Build all platforms, archive with version suffix (zip for
## darwin/windows, tar.gz for linux), bundle the canonical binary +
## README.md + LICENSE, and notarize the darwin build. Asset naming
## follows the org Release Archive Standard
## (json-to-sqlite-vX.Y.Z-<os>-<arch>.<ext>).
package: build-all
	@cd dist && for p in $(PLATFORMS); do os=$${p%/*}; arch=$${p#*/}; \
		ext=""; [ "$$os" = windows ] && ext=".exe"; \
		stage=_pkg; rm -rf $$stage; mkdir -p $$stage; \
		cp "$(BINARY)-$$os-$$arch$$ext" "$$stage/$(BINARY)$$ext"; \
		cp ../README.md ../LICENSE $$stage/; \
		base="$(BINARY)-$(VERSION)-$$os-$$arch"; \
		if [ "$$os" = linux ]; then ( cd $$stage && tar -czf "../$$base.tar.gz" * ); \
		else ( cd $$stage && zip -q "../$$base.zip" * ); fi; \
		rm -rf $$stage; \
	done
	@scripts/notarize-darwin.sh dist/$(BINARY)-$(VERSION)-darwin-arm64.zip "$(NOTARY_PROFILE)"

## verify-release: refuse to release an un-notarized zip (marker gate)
verify-release:
	@test -f "dist/$(BINARY)-$(VERSION)-darwin-arm64.zip.notarized" || { \
		echo "verify-release: FAIL — $(BINARY)-$(VERSION)-darwin-arm64.zip has no notarization marker."; \
		echo "  make package must end with '[notarize] ...: Accepted'. Do not upload this zip."; \
		exit 1; }
	@test "dist/$(BINARY)-$(VERSION)-darwin-arm64.zip.notarized" -nt "dist/$(BINARY)-$(VERSION)-darwin-arm64.zip" || { \
		echo "verify-release: FAIL — the zip was rebuilt after its marker (re-run make package)."; \
		exit 1; }
	@tmp=$$(mktemp -d) && \
		unzip -oq "dist/$(BINARY)-$(VERSION)-darwin-arm64.zip" -d "$$tmp" && \
		"$$tmp/$(BINARY)" --version && \
		spctl -a -vv -t install "$$tmp/$(BINARY)" 2>&1 | head -2 || true; \
		rm -rf "$$tmp"
	@echo "verify-release: OK ($(VERSION), notarization marker present)"

## clean: Remove build artifacts
clean:
	rm -rf dist/

## help: Show this help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'

# Homebrew tap generation (see scripts/release-brew.mk). After `make package`,
# `make brew` generates this formula from the built darwin-arm64 zip into the
# local nlink-jp/homebrew-tap checkout. The package target is unchanged.
BREW_KIND := formula
BREW_DESC := Convert JSON to SQLite with automatic schema inference
include scripts/release-brew.mk
