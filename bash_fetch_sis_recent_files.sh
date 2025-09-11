#!/bin/bash
# Canvas API credentials
TOKEN="put valid user token here"
BASE_URL="put valid canvas api endpoint here"
ACCOUNT_ID="put account id here"
OUTFILE="sis_output_recents_$(date +%F).json"

echo "Fetching the most recent 10 SIS import records..."
curl -s -H "Authorization: Bearer $TOKEN" \
     "$BASE_URL/api/v1/accounts/$ACCOUNT_ID/sis_imports?per_page=10" | jq . > "$OUTFILE"

echo "Done. Output saved to $OUTFILE"
