BINARY  := json-to-sqlite
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
# Note: capital V — matches `var Version string` in main.go
LDFLAGS := -ldflags "-X main.Version=$(VERSION)"

PLATFORMS := \
	linux/amd64 \
	linux/arm64 \
	darwin/amd64 \
	darwin/arm64 \
	windows/amd64

.PHONY: build build-all test lint check package clean help

## build: Build for the current platform
build:
	@mkdir -p dist
	go build $(LDFLAGS) -o dist/$(BINARY) .

## build-all: Cross-compile for all target platforms
# CGO is required for go-sqlite3. Cross-compilers must be installed for non-native targets:
#   Linux amd64: CC=x86_64-linux-musl-gcc  (brew install FiloSottile/musl-cross/musl-cross)
#   Linux arm64: CC=aarch64-linux-musl-gcc
#   Windows:     CC=x86_64-w64-mingw32-gcc (brew install mingw-w64)
build-all:
	@mkdir -p dist
	CGO_ENABLED=1                                          GOOS=darwin  GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-amd64       .
	CGO_ENABLED=1                                          GOOS=darwin  GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-arm64       .
	CGO_ENABLED=1 CC=x86_64-linux-musl-gcc                GOOS=linux   GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-linux-amd64        .
	CGO_ENABLED=1 CC=aarch64-linux-musl-gcc               GOOS=linux   GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-linux-arm64        .
	CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc               GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-windows-amd64.exe  .

## test: Run the full test suite
test:
	go test -race -cover ./...

## lint: Run golangci-lint
lint:
	golangci-lint run ./...

## check: Run lint + test + build-all
check: lint test build-all

## package: Build and package binaries as .zip archives for all platforms
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
