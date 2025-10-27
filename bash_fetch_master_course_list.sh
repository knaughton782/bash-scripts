#!/bin/bash


# Output file and folder for this fetch
TODAY=$(date +"%Y-%m-%d")
OUTPUT_FOLDER="./COURSE-LISTS"
mkdir -p "$OUTPUT_FOLDER"

# Generate unique output filename to avoid overwrite
base_name="courses_$(date +%F)"
extension=".json"
OUTFILE="$OUTPUT_FOLDER/${base_name}${extension}"

# Check if file exists and rename using a, b, c, ... suffix
suffix="a"
while [[ -f "$OUTFILE" ]]; do
    OUTFILE="$OUTPUT_FOLDER/${base_name}${suffix}${extension}"
    suffix=$(echo "$suffix" | tr "a-y" "b-z")  # next letter
done


if [ -d "$OUTPUT_FOLDER" ]; then
    echo "Folder $OUTPUT_FOLDER already exists. Saving file inside it..."
fi

# Canvas API credentials
TOKEN="put token here"
# master course subaccount ID 
SUBACCOUNT_ID="put subaccount ID here"
BASE_URL="https://YOUR-INSTITUTION/api/v1/accounts/$SUBACCOUNT_ID/courses"
COURSE_CSV="courses_$TODAY.csv"

echo "Fetching courses from subaccount $SUBACCOUNT_ID..."

TMPFILE="$OUTPUT_FOLDER/tmp_courses.json"
> "$TMPFILE"

page=1
while : ; do
    echo "Fetching page $page..."
    RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL?per_page=100&page=$page")    

    
    COUNT=$(echo "$RESPONSE" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
        break
    fi

    echo "$RESPONSE" >> "$TMPFILE"
    ((page++))
done

jq -s 'add' "$TMPFILE" > "$OUTFILE"
rm "$TMPFILE"

jq -r '
  (["id","sis_course_id","name","course_code","start_at","end_at"] | @csv),
  (.[] | [.id, .sis_course_id, .name, .course_code, .start_at, .end_at] | @csv)
' "$OUTFILE" > "$OUTPUT_FOLDER/$COURSE_CSV"


COURSE_COUNT=$(jq 'length' "$OUTFILE")
echo "Fetched $COURSE_COUNT courses. JSON saved to $OUTFILE and CSV saved to $OUTPUT_FOLDER/$COURSE_CSV."

# Fetch CSV attachments and errors attachments URLs and download them
IMPORTS_URL="https://YOUR-INSTITUTION/api/v1/accounts/$SUBACCOUNT_ID/imports"
IMPORTS_JSON="$OUTPUT_FOLDER/imports.json"
curl -s -H "Authorization: Bearer $TOKEN" "$IMPORTS_URL" > "$IMPORTS_JSON"

urls=($(jq -r '
  .[] | 
  (.csv_attachments[]?.url),
  (.errors_attachment.url // empty)
' "$IMPORTS_JSON" | sort -u))

for url in "${urls[@]}"; do
    filename=$(basename "$url")
    if [[ -z "$filename" ]]; then
        filename="downloaded_file"
    fi
    echo "Downloading $filename from $url..."
    curl -s -H "Authorization: Bearer $TOKEN" -o "$OUTPUT_FOLDER/$filename" "$url"
done

rm "$IMPORTS_JSON"
