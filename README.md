# json-to-sqlite

A flexible command-line tool that ingests JSON data and intelligently converts it into an SQLite database.

This tool automatically infers table schemas, handles schema evolution by adding new columns on the fly, and processes JSON from either files or standard input, making it a powerful utility for data wrangling and persistence.

## Features

-   **Automatic Schema Inference**: Intelligently generates SQLite table schemas from the structure of your JSON objects.
-   **Automatic Schema Evolution**: Seamlessly updates existing tables by adding new columns when new fields are detected in the input data.
-   **Flexible Input**: Reads JSON data from files or piped directly from standard input.
-   **Data Type Mapping**: Automatically maps JSON types to appropriate SQLite types (`TEXT`, `REAL`, `INTEGER`). Defaults to `TEXT` for safety in case of conflicting types.
-   **Handles Nested JSON**: Serializes nested JSON objects and arrays into `TEXT` columns.
-   **Cross-Platform**: Builds for Windows, Linux, and macOS (Universal Binary) via the provided `Makefile`.

## Installation

### From Release
Download the latest pre-compiled binary for your operating system from the [Releases](https://github.com/magifd2/json-to-sqlite/releases) page.

### From Source
To build from source, you will need Go and Make installed.

```bash
# 1. Clone the repository
git clone https://github.com/magifd2/json-to-sqlite.git
cd json-to-sqlite

# 2. Build the binary
make build

# The executable will be in ./bin/<os>-<arch>/
# For example: ./bin/darwin-universal/json-to-sqlite
```

## Usage

The tool requires an input JSON file and the following flags:

-   `-o <path>`: **Required.** Specifies the path for the output SQLite database file.
-   `-t <name>`: **Required.** Specifies the name of the table to create or update.
-   `--version`: Prints the current version of the tool.

### Examples

**1. Convert a JSON file into a new database:**
```bash
json-to-sqlite -o users.db -t users users.json
```

**2. Pipe JSON data from another command (e.g., `curl`):**
```bash
curl "https://api.example.com/data" | json-to-sqlite -o api_data.db -t records -
```
*Note: When piping from stdin, use `-` as the input_json_file argument.*

**3. Add new data with potentially new columns to an existing database:**
```bash
# This second command might add new columns to the 'users' table if new_users.json has different fields
json-to-sqlite -o users.db -t users new_users.json
```

## How It Works

### Type Mapping
JSON types are mapped to SQLite types as follows:
-   `string` -> `TEXT`
-   `number` -> `REAL`
-   `boolean` -> `INTEGER` (1 for `true`, 0 for `false`)
-   `array` -> `TEXT` (stored as a JSON string)
-   `object` -> `TEXT` (stored as a JSON string)

If multiple objects have the same key but different data types, the column type will be promoted to `TEXT` to ensure all data can be stored without loss.

## License

This project is licensed under the [MIT License](LICENSE).