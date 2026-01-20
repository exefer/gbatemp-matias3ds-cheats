#!/usr/bin/env bash
set -eu
shopt -s nullglob

USER_AGENT=gbatemp-matias3ds-cheats
HTML=$(curl -A "$USER_AGENT" -s https://gbatemp.net/threads/cheat-codes-ams-and-sx-os-add-and-request.520293/)
HREF=$(grep -oE 'href="/attachments/titles-rar\.[0-9]+/' <<< "$HTML" | cut -c8-)

echo "Downloading titles archive..."
rm -rf titles/
curl -A "$USER_AGENT" -o titles.rar -s "https://gbatemp.net/$HREF"

echo "Extracting archive..."
unrar x -inul titles.rar

echo "Uppercasing directory names..."
for d in titles/*/; do
    base=$(basename "$d")
    upper=${base^^}
    if [[ "$base" != "$upper" ]]; then
        mv "$d" "titles/$upper"
    fi
done

echo "Renaming Cheats to cheats..."
find titles/ -type d -name "Cheats" | while read -r dir; do
    parent=$(dirname "$dir")
    mv "$dir" "$parent/cheats"
done

is_valid_switch_id() {
    local id="$1"
    # Valid Switch ID: 16 hex characters
    [[ $id =~ ^[A-F0-9]{16}$ ]]
}

echo "Processing cheat files..."
for d in titles/*/; do
    if [[ ! -d "$d/cheats" ]]; then
        mkdir -p "$d/cheats"
    fi

    # Move valid .txt files to cheats directory
    for f in "$d"/*.txt; do
        [[ -f "$f" ]] || continue
        filename=$(basename "$f" .txt)
        uppername=${filename^^}
        if is_valid_switch_id "$uppername"; then
            mv "$f" "$d/cheats/$uppername.txt"
        else
            rm -f "$f"
        fi
    done

    # Clean up cheats directory: remove non-.txt files and uppercase filenames
    for f in "$d"/cheats/*; do
        [[ -f "$f" ]] || continue
        if [[ "${f##*.}" != "txt" ]]; then
            rm -f "$f"
        else
            base=$(basename "$f" .txt)
            upper=${base^^}
            # Remove files with invalid names (containing spaces, dashes, etc)
            if ! is_valid_switch_id "$upper"; then
                rm -f "$f"
            elif [[ "$base" != "$upper" ]]; then
                mv "$f" "$d/cheats/$upper.txt"
            fi
        fi
    done

    # Remove any remaining files/folders in title directory (not in cheats/)
    for item in "$d"/*; do
        [[ -e "$item" ]] || continue
        if [[ "$(basename "$item")" != "cheats" ]]; then
            rm -rf "$item"
        fi
    done

    # Remove directories with no cheats
    if [[ ! $(ls -A "$d/cheats") ]]; then
        rm -rf "$d"
    fi
done

rm -rf titles.rar

echo
echo "Done!"

if [[ -n $(git status --porcelain) ]]; then
    echo "Changes detected. Committing changes..."
    git add .
    git commit -m "Update cheats"
else
    echo "No changes to commit. Exiting."
fi
