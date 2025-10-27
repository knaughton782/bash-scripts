#!/bin/bash

# File to store the last fetch time
TIMESTAMP_FILE="last_fetch_timestamp.txt"

# Output file for this fetch
TODAY=$(date +"%Y-%m-%d")

# Create a dated output folder
OUTPUT_FOLDER="./$TODAY"
mkdir -p "$OUTPUT_FOLDER"

# Generate unique output filename to avoid overwrite
base_name="sis_output_$(date +%F)"
extension=".json"
OUTFILE="$OUTPUT_FOLDER/${base_name}${extension}"

# Check if file exists and rename using a, b, c, ... suffix
suffix="a"
while [[ -f "$OUTFILE" ]]; do
    OUTFILE="$OUTPUT_FOLDER/${base_name}${suffix}${extension}"
    suffix=$(echo "$suffix" | tr "a-y" "b-z")  # next letter
done
# OUTFILE="$OUTPUT_FOLDER/sis_output_$(date +%F).json"

if [ -d "$OUTPUT_FOLDER" ]; then
    echo "Folder $OUTPUT_FOLDER already exists. Saving file inside it..."
fi

# Canvas API credentials
TOKEN="put valid user token here"
BASE_URL="put valid canvas api endpoint here"


# Default to 2 days ago if timestamp file doesn't exist
if [[ -f "$TIMESTAMP_FILE" ]]; then
    SINCE=$(cat "$TIMESTAMP_FILE")
else
    SINCE=$(date -u -v-2d +"%Y-%m-%dT%H:%M:%SZ")  # macOS-compatible UTC time 2 days ago
fi

echo "Fetching data since $SINCE..."

# Call Canvas API for SIS imports since that date
echo "Fetching SIS imports from Canvas (paginated)..."

TMPFILE="$OUTPUT_FOLDER/tmp_combined.json"
> "$TMPFILE"

page=1
while : ; do
    echo "Fetching page $page..."
    RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL?created_since=$SINCE&per_page=100&page=$page")
    
    # Check if response is empty
    COUNT=$(echo "$RESPONSE" | jq '.sis_imports | length')
    if [[ "$COUNT" -eq 0 ]]; then
        break
    fi

    echo "$RESPONSE" >> "$TMPFILE"
    ((page++))
done

# Combine and flatten into a valid JSON array of SIS imports
jq -s '[.[] | .sis_imports[]]' "$TMPFILE" > "$OUTFILE"
rm "$TMPFILE"

# Update timestamp for next fetch (current UTC time)
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$TIMESTAMP_FILE"

echo "Parsing $OUTFILE for URLs and downloading associated files..."

urls=$(jq -r '
  .[]?
  | select(.csv_attachments and (.csv_attachments | length > 0))
  | .csv_attachments[]
  | .url
' "$OUTFILE")

if [ -z "$urls" ]; then
    note_file="${OUTFILE%.json}_NO_FILES_FOUND.txt"
    echo "No downloadable URLs found." > "$note_file"
    echo "No attachments found. Logged to $note_file."
    exit 0
fi

echo "$urls" | while read -r url; do
    if [[ -n "$url" ]]; then
        display_name=$(jq -r --arg url "$url" '
          .[]?
          | select(.csv_attachments and (.csv_attachments | length > 0))
          | .csv_attachments[]
          | select(.url == $url)
          | .display_name
        ' "$OUTFILE")
        filename="${display_name:-$(basename "$url")}"
        curl -s -L -H "Authorization: Bearer $TOKEN" "$url" -o "$OUTPUT_FOLDER/$filename"
        echo "Downloaded $filename to $OUTPUT_FOLDER"
    fi
done

# Download .errors_attachment.url files
ERRORS_URLS=$(echo "$IMPORT_DETAILS" | jq -r '.[] | select(.errors_attachment != null) | .errors_attachment.url' | grep -v null || true)

if [ -n "$ERRORS_URLS" ]; then
  echo "$ERRORS_URLS" | while read -r url; do
    if [ -n "$url" ]; then
      curl -s -H "Authorization: Bearer $TOKEN" --remote-header-name --remote-name --output-dir "$OUTPUT_FOLDER" "$url"
      echo "Downloaded errors_attachment file from URL: $url"
    fi
  done
fi

# Create a ZIP archive of all non-JSON files
ZIP_NAME="imports_and_errors_$TODAY.zip"
echo "Creating ZIP file $ZIP_NAME excluding JSON files..."
(cd "$OUTPUT_FOLDER" && zip -r "$ZIP_NAME" . -x "*.json")
echo "ZIP file created at $OUTPUT_FOLDER/$ZIP_NAME"