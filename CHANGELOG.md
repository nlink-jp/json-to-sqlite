# Changelog

## v1.2.4 - 2026-05-23

### Changed

- **Darwin releases are now Developer ID signed and Apple-notarized.**
  `json-to-sqlite-v1.2.4-darwin-{amd64,arm64}.zip` carry full Apple
  Developer ID Application signatures and notarization tickets from
  Apple. End users on macOS no longer need to bypass Gatekeeper
  with right-click → Open or `xattr -d com.apple.quarantine` on
  first launch; local users who place `json-to-sqlite` under
  Dropbox-synced (or any other FileProvider-managed) paths are no
  longer killed by macOS's ad-hoc + provenance distrust policy.
  Pipeline: `scripts/codesign-darwin.sh` +
  `scripts/notarize-darwin.sh`, driven by `make package`. Adopts
  the org-wide convention in `nlink-jp/.github` CONVENTIONS.md
  §Code Signing.

### Fixed

- **Windows CGO cross-compile updated to UCRT64 toolchain.**
  Preemptively adopts the toolchain switch and `ranlib` workaround
  established in `gem-query v0.3.2` — Debian's mingw packaging
  ships archives without an index that the default
  `gcc-mingw-w64-x86-64` chain fails to link against modern CGO
  C/C++ runtimes. Switch:
  `gcc-mingw-w64-ucrt64` + `g++-mingw-w64-ucrt64`, with
  `x86_64-w64-mingw32ucrt-ranlib` over every toolchain archive
  before `go build`. Result: the CGO link against
  `mattn/go-sqlite3` continues to work even as the upstream
  Debian Go image's mingw alternatives drift.

No behaviour change to the binary itself — feature-wise this is
identical to v1.2.3.

## v1.2.3 - 2026-03-28

### Changed
- Makefile: replace hardcoded musl-cross/mingw-w64 cross-compiler flags with Podman-based container builds for Linux (amd64/arm64) and Windows (amd64), following the lite-rag pattern. Adds `build-darwin`, `build-linux`, `build-linux-native`, `build-windows` targets. `check` now depends only on `build-darwin` (no container required for local dev).

## v1.2.2 - 2026-03-28

### Changed
- Unified Makefile: replaced macOS universal binary with separate `darwin/amd64` and `darwin/arm64` targets; standardized targets (`build`, `build-all`, `test`, `lint`, `check`, `package`, `clean`, `help`) and output layout (`dist/` flat directory, `.zip` archives).

## v1.2.1 - 2026-03-28

### Internal

- Updated Go module path to `github.com/nlink-jp/json-to-sqlite` following repository transfer to nlink-jp organization.

## v1.2.0 - 2025-09-12

### Fixed
- The tool now correctly reads from standard input when no input file is specified or when '-' is used as the file name, allowing for proper pipeline usage.

### Changed
- Improved the CLI help message for clarity, explicitly marking required flags and providing a better usage example.
- Updated and synchronized `README.md` and `README.ja.md` to accurately reflect the tool's argument handling and usage.

## v1.1.0 - 2025-09-11

### Added
- Made input JSON file, output SQLite database file (-o), and table name (-t) mandatory arguments.
- Removed default values for -o and -t flags.

## v1.0.1 - 2025-09-11

### Fixed
- Implemented robust SQL identifier quoting to prevent syntax errors with JSON keys containing special characters (e.g., double quotes).

## v1.0.0 - 2025-09-11

### Added
- Initial release of `json-to-sqlite` command-line tool.
- Convert JSON data from standard input or file to SQLite database.
- Automatic schema inference based on JSON structure.
- Automatic schema evolution (add columns) for existing tables.
- Support for various JSON data types (string, number, boolean) mapped to SQLite (TEXT, REAL, INTEGER).
- Handles nested JSON objects and arrays by serializing them to TEXT.
- Cross-platform build support (macOS, Linux, Windows) via `Makefile`.
- macOS Universal Binary support.
- Dynamic versioning from Git tags.
- Comprehensive `README.md` (English) and `README.ja.md` (Japanese) documentation.