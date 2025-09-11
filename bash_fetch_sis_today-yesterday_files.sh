#!/bin/bash
TOKEN="put valid user token here"
BASE_URL="put valid canvas api endpoint here"
ACCOUNT_ID="put account id here"
OUTFILE="sis_output_recents_$(date +%F).json"

# Get today's and yesterday's dates in YYYY-MM-DD format (Mac BSD `date`)
TODAY=$(date "+%Y-%m-%d")
YESTERDAY=$(date -v-1d "+%Y-%m-%d")

# Fetch the last 20 SIS imports and saves raw output to a file
echo "Fetching the most recent 20 SIS import records..."
curl -s -H "Authorization: Bearer $TOKEN" \
     "$BASE_URL/api/v1/accounts/$ACCOUNT_ID/sis_imports?per_page=20"  > sis_output_recent-20_raw.json

# Filter raw data for records from TODAY or YESTERDAY
jq "[.sis_imports[] | select(.created_at | startswith(\"$TODAY\") or startswith(\"$YESTERDAY\"))]" \
  sis_output_recent-20_raw.json > "sis_output_recent_${TODAY}.json"

echo "Done. Filtered output saved to sis_output_recent_${TODAY}.json"
