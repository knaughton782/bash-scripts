#!/bin/bash

# Organize CSV, TXT, and Excel files by filesystem creation date
for file in *.csv *.txt *.xls *.xlsx; do
  [[ -e "$file" ]] || continue

  # Try to extract date from filename (e.g., 2025-09-05)
  if [[ "$file" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    folder_date="${BASH_REMATCH[1]}"
  else
    # Get file creation date using stat (macOS format)
    folder_date=$(stat -f "%SB" -t "%Y-%m-%d" "$file" 2>/dev/null)
    [[ -z "$folder_date" ]] && folder_date="unknown-date"
  fi

  # Create folder and move the file
  mkdir -p "$folder_date"
  mv "$file" "$folder_date/"
done

echo "✅ Files organized by macOS file creation date."