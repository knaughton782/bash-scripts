#!/bin/bash

# Load environment variables from .env file
set -o allexport
source .env
set +o allexport

TOKEN="$CANVAS_TOKEN"
BASE_URL="$BASE_DOMAIN/api/v1/accounts/$ACCOUNT_ID/sis_imports"
OUTFILE="sis_output_recent-20-filtered_$(date +%F).json"

# Get today's and yesterday's dates in YYYY-MM-DD format (Mac BSD `date`)
TODAY=$(date "+%Y-%m-%d")
YESTERDAY=$(date -v-1d "+%Y-%m-%d")

# Fetch the last 20 SIS imports and saves raw output to a file
echo "Fetching the most recent 20 SIS import records..."
curl -s -H "Authorization: Bearer $TOKEN" \
     "$BASE_URL?per_page=20"  > sis_output_recent-20_raw.json

# Filter raw data for records from TODAY or YESTERDAY
jq "[.sis_imports[] | select(.created_at | startswith(\"$TODAY\") or startswith(\"$YESTERDAY\"))]" \
  sis_output_recent-20_raw.json > "sis_output_recent_${TODAY}.json"

echo "Done. Filtered output saved to sis_output_recent_${TODAY}.json"
