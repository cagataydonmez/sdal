#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MDB_DIR="${MDB_DIR:-/Users/cagataydonmez/Desktop/SDAL}"
OUT_DB="${OUT_DB:-$ROOT_DIR/db/sdal.sqlite}"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/db/tmp}"

MDB_FILES=(
  "$MDB_DIR/datamizacx.mdb"
  "$MDB_DIR/aiacx.mdb"
  "$MDB_DIR/oyunlar.mdb"
  "$MDB_DIR/turnuvadata.mdb"
)

command -v mdb-schema >/dev/null 2>&1 || { echo "mdb-schema not found. Install mdbtools."; exit 1; }
command -v mdb-tables >/dev/null 2>&1 || { echo "mdb-tables not found. Install mdbtools."; exit 1; }
command -v mdb-export >/dev/null 2>&1 || { echo "mdb-export not found. Install mdbtools."; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 not found."; exit 1; }

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

SCHEMA_FILE="$TMP_DIR/schema.sql"
: > "$SCHEMA_FILE"

for mdb in "${MDB_FILES[@]}"; do
  if [ ! -f "$mdb" ]; then
    echo "Skipping missing $mdb"
    continue
  fi
  echo "Generating schema for $mdb"
  mdb-schema "$mdb" sqlite >> "$SCHEMA_FILE"
  echo "" >> "$SCHEMA_FILE"

done

rm -f "$OUT_DB"
sqlite3 "$OUT_DB" < "$SCHEMA_FILE"

for mdb in "${MDB_FILES[@]}"; do
  if [ ! -f "$mdb" ]; then
    continue
  fi
  echo "Exporting data from $mdb"
  while IFS= read -r table; do
    if [ -z "$table" ]; then
      continue
    fi
    csv="$TMP_DIR/$table.csv"
    mdb-export -H -D '%Y-%m-%d %H:%M:%S' "$mdb" "$table" > "$csv"
    # import into sqlite, skipping header row
    sqlite3 "$OUT_DB" <<SQL
.mode csv
.import --skip 1 '$csv' $table
SQL
  done < <(mdb-tables -1 "$mdb")

done

echo "SQLite database created at $OUT_DB"
