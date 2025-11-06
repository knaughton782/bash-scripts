#!/bin/bash

# Load environment variables from .env file
set -o allexport
source .env
set +o allexport

# Canvas API credentials
TOKEN="$CANVAS_TOKEN"
BASE_URL="$BASE_DOMAIN/api/v1/accounts/$ACCOUNT_ID/sis_imports"

# File to store the last fetch time
TIMESTAMP_FILE="last_fetch_timestamp.txt"

# Output file for this fetch
TODAY=$(date +"%Y-%m-%d")

# Create a dated output folder
OUTPUT_FOLDER="../$TODAY"
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




# Default to 3 days ago if timestamp file doesn't exist
if [[ -f "$TIMESTAMP_FILE" ]]; then
    SINCE=$(cat "$TIMESTAMP_FILE")
else
    SINCE=$(date -u -v-3d +"%Y-%m-%dT%H:%M:%SZ")  # macOS-compatible UTC time 3 days ago
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
IMPORT_DETAILS=$(cat "$OUTFILE")


#
# Download .csv_attachments[] files with unique filenames
echo "$IMPORT_DETAILS" | jq -c '.[] | select(.csv_attachments and (.csv_attachments | length > 0)) | .csv_attachments[]' | while read -r row; do
  # echo "Raw attachment row: $row"
  ATTACHMENT_URL=$(echo "$row" | jq -r '.url')
  ATTACHMENT_NAME=$(echo "$row" | jq -r '.display_name')


  # Ensure unique filename by appending a, b, etc. if needed (no underscore)
  BASENAME="${ATTACHMENT_NAME%.*}"
  EXTENSION="${ATTACHMENT_NAME##*.}"
  SUFFIX=""
  COUNTER=97  # ASCII 'a'

  while [[ -e "$OUTPUT_FOLDER/${BASENAME}${SUFFIX}.$EXTENSION" ]]; do
    SUFFIX=$(printf \\$(printf '%03o' $COUNTER))
    ((COUNTER++))
  done

  UNIQUE_FILENAME="${BASENAME}${SUFFIX}.$EXTENSION"

  echo "Trying to download: $ATTACHMENT_URL"
  curl -sSL -H "Authorization: Bearer $TOKEN" "$ATTACHMENT_URL" -o "$OUTPUT_FOLDER/$UNIQUE_FILENAME"
  echo "Downloaded attachment: $UNIQUE_FILENAME"
done

# Download .errors_attachment.url files with assigned names
echo "$IMPORT_DETAILS" | jq -c '.[] | select(.errors_attachment != null)' | while read -r item; do
  ERRORS_URL=$(echo "$item" | jq -r '.errors_attachment.url')
  IMPORT_ID=$(echo "$item" | jq -r '.id')
  CSV_BASE_NAMES=$(echo "$item" | jq -r '.csv_attachments[]?.display_name' | sed 's/\.[^.]*$//' | paste -sd "-" -)
  ERROR_FILE_NAME="sis_errors_${IMPORT_ID}_${CSV_BASE_NAMES}.csv"

  if [ -n "$ERRORS_URL" ] && [ "$ERRORS_URL" != "null" ]; then
    echo "Trying to download error file: $ERROR_FILE_NAME from $ERRORS_URL"

    BASENAME="${ERROR_FILE_NAME%.*}"
    EXTENSION="${ERROR_FILE_NAME##*.}"
    SUFFIX=""
    COUNTER=97  # ASCII 'a'

    while [[ -e "$OUTPUT_FOLDER/${BASENAME}${SUFFIX}.$EXTENSION" ]]; do
      SUFFIX=$(printf \\$(printf '%03o' $COUNTER))
      ((COUNTER++))
    done

    UNIQUE_FILENAME="${BASENAME}${SUFFIX}.$EXTENSION"

    curl -sSL -H "Authorization: Bearer $TOKEN" "$ERRORS_URL" -o "$OUTPUT_FOLDER/$UNIQUE_FILENAME"
    echo "Downloaded errors_attachment: $UNIQUE_FILENAME"
  fi
done

# Create a ZIP archive of all CSV files only
ZIP_NAME="imports_and_errors_$TODAY.zip"
echo "Creating ZIP file $ZIP_NAME with only CSV files..."
zip -j "$OUTPUT_FOLDER/$ZIP_NAME" "$OUTPUT_FOLDER"/*.csv 2>/dev/null
echo "ZIP file created at $OUTPUT_FOLDER/$ZIP_NAME"