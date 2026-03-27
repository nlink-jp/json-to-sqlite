# Changelog

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