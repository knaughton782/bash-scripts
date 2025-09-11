#!/bin/bash
# Canvas API credentials
TOKEN="put valid user token here"
BASE_URL="put valid canvas api endpoint here"
OUTFILE="sis_output_$(date +%F).json"

# Start of JSON array
echo "[" > "$OUTFILE"

# Loop through 10 pages of SIS import results
for i in {1..10}; do
  echo "Fetching page $i..."
  curl -s -H "Authorization: Bearer $TOKEN" \
       "$BASE_URL?per_page=100&page=$i" | jq . >> "$OUTFILE"

  # Add a comma unless it's the last item
  if [ "$i" -lt 10 ]; then
    echo "," >> "$OUTFILE"
  fi
done

# End of JSON array
echo "]" >> "$OUTFILE"

echo "Done. Output saved to $OUTFILE"
