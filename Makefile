BINARY  := json-to-sqlite
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
# Note: capital V — matches `var Version string` in main.go
LDFLAGS := -ldflags '-X main.Version=$(VERSION)'

# Container runtime (podman preferred, docker as fallback)
CONTAINER := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
# Go image used for container builds — must match go.mod toolchain.
GO_IMAGE  := golang:1.26

PLATFORMS := \
	linux/amd64 \
	linux/arm64 \
	darwin/amd64 \
	darwin/arm64 \
	windows/amd64

.PHONY: build build-all build-darwin build-linux build-linux-native build-windows \
        test lint check package clean help

## build: Build for the current platform
build:
	@mkdir -p dist
	go build $(LDFLAGS) -o dist/$(BINARY) .

## build-all: Cross-compile for all target platforms
build-all: build-darwin build-linux build-windows

## build-darwin: Compile darwin/amd64 and darwin/arm64 (macOS host only)
build-darwin:
	@mkdir -p dist
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-amd64 .
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-arm64 .

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
		bash -c "apt-get update -qq && apt-get install -y -q gcc-mingw-w64-x86-64 \
			&& GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc \
			go build $(LDFLAGS) -o dist/$(BINARY)-windows-amd64.exe ."

## test: Run the full test suite
test:
	go test -race -cover ./...

## lint: Run golangci-lint
lint:
	golangci-lint run ./...

## check: Run lint + test + build-darwin
check: lint test build-darwin

## package: Build all platforms and create .zip archives
package: build-all
	$(foreach platform,$(PLATFORMS), \
		$(eval GOOS=$(word 1,$(subst /, ,$(platform)))) \
		$(eval GOARCH=$(word 2,$(subst /, ,$(platform)))) \
		$(eval EXT=$(if $(filter windows,$(GOOS)),.exe,)) \
		$(eval ARCHIVE=dist/$(BINARY)-$(VERSION)-$(GOOS)-$(GOARCH).zip) \
		zip -j $(ARCHIVE) dist/$(BINARY)-$(GOOS)-$(GOARCH)$(EXT) LICENSE README.md ; \
	)

## clean: Remove build artifacts
clean:
	rm -rf dist/

## help: Show this help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'
