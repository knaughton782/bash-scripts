

#!/bin/bash

# Loop through all files in the current directory
for file in *; do
  # Skip directories
  [ -f "$file" ] || continue

  # Remove leading 'null_' or '_'
  new_name="$file"
  new_name="${new_name#null_}"
  new_name="${new_name#_}"

  # Rename the file if the name has changed
  if [[ "$file" != "$new_name" ]]; then
    mv -- "$file" "$new_name"
    echo "Renamed: '$file' -> '$new_name'"
  fi
done