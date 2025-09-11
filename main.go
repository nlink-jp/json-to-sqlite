package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"sort"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

// Version is set at build time using -ldflags
var Version string

func main() {
	// --- CLI Setup ---
	if Version == "" {
		Version = "dev"
	}

	outputDB := flag.String("o", "output.db", "Output SQLite database file")
	tableName := flag.String("t", "data", "Table name to insert data into")
	versionFlag := flag.Bool("version", false, "Print version information")

	flag.Parse()

	if *versionFlag {
		fmt.Printf("json-to-sqlite version %s\n", Version)
		return
	}

	// --- Input Handling ---
	reader, err := getInputReader(flag.Args())
	if err != nil {
		log.Fatal(err)
	}

	// --- JSON Parsing ---
	data, err := decodeJSON(reader)
	if err != nil {
		log.Fatalf("Error decoding JSON: %v", err)
	}
	if len(data) == 0 {
		log.Println("No JSON objects to process.")
		return
	}

	// --- Database Logic ---
	db, err := openDatabase(*outputDB)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}
	defer db.Close()

	finalColumns, err := setupTable(db, *tableName, data)
	if err != nil {
		log.Fatalf("Error setting up table: %v", err)
	}

	err = insertData(db, *tableName, finalColumns, data)
	if err != nil {
		log.Fatalf("Error inserting data: %v", err)
	}

	fmt.Printf("Successfully processed %d objects into table '%s' in database '%s'.\n", len(data), *tableName, *outputDB)
}

func getInputReader(args []string) (io.Reader, error) {
	if len(args) > 0 {
		filePath := args[0]
		file, err := os.Open(filePath)
		if err != nil {
			return nil, fmt.Errorf("error opening file %s: %w", filePath, err)
		}
		return file, nil
	}
	return os.Stdin, nil
}

func decodeJSON(reader io.Reader) ([]map[string]interface{}, error) {
	content, err := io.ReadAll(reader)
	if err != nil {
		return nil, fmt.Errorf("failed to read input: %w", err)
	}

	var data []map[string]interface{}
	if json.Unmarshal(content, &data) == nil {
		return data, nil
	}

	var singleObject map[string]interface{}
	if json.Unmarshal(content, &singleObject) == nil {
		return []map[string]interface{}{singleObject}, nil
	}

	return nil, fmt.Errorf("failed to decode JSON as an array of objects or a single object")
}

func openDatabase(dbPath string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}
	return db, nil
}

func inferSchema(data []map[string]interface{}) map[string]string {
	columnTypes := make(map[string]string)
	for _, row := range data {
		for key, value := range row {
			var currentType string
			if value == nil {
				continue // Cannot infer type from null, wait for a non-null value
			}
			switch reflect.TypeOf(value).Kind() {
			case reflect.String:
				currentType = "TEXT"
			case reflect.Float64:
				currentType = "REAL"
			case reflect.Bool:
				currentType = "INTEGER"
			default:
				// For complex types (objects, arrays), serialize as JSON string
				currentType = "TEXT"
			}

			if existingType, ok := columnTypes[key]; ok {
				if existingType != currentType && existingType != "TEXT" {
					columnTypes[key] = "TEXT" // Upgrade to TEXT if types conflict
				}
			} else {
				columnTypes[key] = currentType
			}
		}
	}
	return columnTypes
}

func setupTable(db *sql.DB, tableName string, data []map[string]interface{}) ([]string, error) {
	inferredSchema := inferSchema(data)

	var tableExists bool
	query := "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
	err := db.QueryRow(query, tableName).Scan(&tableName)
	if err == nil {
		tableExists = true
	} else if err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to check if table exists: %w", err)
	}

	if !tableExists {
		var columns []string
		for name, colType := range inferredSchema {
			columns = append(columns, fmt.Sprintf("\"%s\" %s", name, colType))
		}
		sort.Strings(columns) // Ensure consistent order for CREATE TABLE
		createQuery := fmt.Sprintf("CREATE TABLE \"%s\" (%s)", tableName, strings.Join(columns, ", "))
		_, err := db.Exec(createQuery)
		if err != nil {
			return nil, fmt.Errorf("failed to create table: %w", err)
		}
	} else {
		// Table exists, check for missing columns
		// Use string concatenation for PRAGMA to avoid any Sprintf formatting issues.
		// Table names can't be parameterized in PRAGMA statements.
		pragmaQuery := "PRAGMA table_info(" + `"` + strings.ReplaceAll(tableName, `"`, `""`) + `"` + ")"
	
rows, err := db.Query(pragmaQuery)
		if err != nil {
			return nil, fmt.Errorf("failed to get existing table info: %w", err)
		}
		defer rows.Close()

		existingColumns := make(map[string]bool)
		for rows.Next() {
			var cid int
			var name string
			var colType string
			var notnull bool
			var dfltValue interface{}
			var pk int
			if err := rows.Scan(&cid, &name, &colType, &notnull, &dfltValue, &pk); err != nil {
				return nil, fmt.Errorf("failed to scan table info row: %w", err)
			}
			existingColumns[name] = true
		}

		for colName, colType := range inferredSchema {
			if !existingColumns[colName] {
				alterQuery := fmt.Sprintf("ALTER TABLE \"%s\" ADD COLUMN \"%s\" %s", tableName, colName, colType)
				_, err := db.Exec(alterQuery)
				if err != nil {
					return nil, fmt.Errorf("failed to add column '%s': %w", colName, err)
				}
			}
		}
	}

	// Return the final list of columns that should be in the table
	finalColumns := make([]string, 0, len(inferredSchema))
	for colName := range inferredSchema {
		finalColumns = append(finalColumns, colName)
	}
	sort.Strings(finalColumns)
	return finalColumns, nil
}

func insertData(db *sql.DB, tableName string, columns []string, data []map[string]interface{}) error {
	if len(data) == 0 {
		return nil
	}

	placeholders := strings.Repeat("?,", len(columns))
	placeholders = placeholders[:len(placeholders)-1]

	query := fmt.Sprintf("INSERT INTO \"%s\" (%s) VALUES (%s)", tableName, "\""+strings.Join(columns, "\", \"")+"\"", placeholders)

	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	stmt, err := tx.Prepare(query)
	if err != nil {
		return fmt.Errorf("failed to prepare insert statement: %w", err)
	}
	defer stmt.Close()

	for _, row := range data {
		values := make([]interface{}, len(columns))
		for i, col := range columns {
			val, ok := row[col]
			if !ok || val == nil {
				values[i] = nil
				continue
			}

			// If the value is a complex type, marshal it back to a JSON string
			kind := reflect.TypeOf(val).Kind()
			if kind == reflect.Map || kind == reflect.Slice {
				jsonBytes, err := json.Marshal(val)
				if err != nil {
					return fmt.Errorf("failed to marshal nested JSON for column '%s': %w", col, err)
				}
				values[i] = string(jsonBytes)
			} else {
				values[i] = val
			}
		}

		_, err := stmt.Exec(values...)
		if err != nil {
			// Attempt to rollback, but return the original error
			_ = tx.Rollback()
			return fmt.Errorf("failed to execute insert: %w", err)
		}
	}

	return tx.Commit()
}
