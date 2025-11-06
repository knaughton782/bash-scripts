#!/bin/bash
set -o allexport
source .env
set +o allexport

# Check for jq availability
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }

TOKEN="$CANVAS_TOKEN"
BASE_URL="$BASE_DOMAIN/api/v1/accounts/$ACCOUNT_ID/sis_imports"
OUTFILE="../sis_output_$(date +%F).json"

# Start of JSON array
echo "[" > "$OUTFILE"

# Loop through 10 pages of SIS import results
for i in {1..10}; do
  echo "Fetching page $i..."
  response=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL?per_page=100&page=$i")
  if [ $? -ne 0 ]; then
    echo "Error fetching page $i"
    exit 1
  fi
  echo "$response" | jq . >> "$OUTFILE"

  # Add a comma unless it's the last item
  if [ "$i" -lt 10 ]; then
    echo "," >> "$OUTFILE"
  fi
done

# End of JSON array
echo "]" >> "$OUTFILE"

echo "Done. Output saved to $OUTFILE"
