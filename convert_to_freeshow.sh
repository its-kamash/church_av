#!/usr/bin/env bash
# convert_to_freeshow.sh
# Converts raw hymn text files to FreeShow-compatible format.
# - Verse markers become [Verse]
# - Refrain markers become [Chorus]
# - Chorus content is automatically duplicated after each verse
#
# USAGE:
#   ./convert_to_freeshow.sh
#   ./convert_to_freeshow.sh -i ./raw_text -o ./FreeShow
#   ./convert_to_freeshow.sh --input ./raw_text --output ./FreeShow/sdah_sw

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
input_folder="raw_text"
output_folder="FreeShow"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)  input_folder="$2";  shift 2 ;;
        -o|--output) output_folder="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Resolve to absolute paths relative to $PWD
[[ "$input_folder"  != /* ]] && input_folder="$(pwd)/$input_folder"
[[ "$output_folder" != /* ]] && output_folder="$(pwd)/$output_folder"

# Strip any trailing slashes for consistency
input_folder="${input_folder%/}"
output_folder="${output_folder%/}"

if [[ ! -d "$input_folder" ]]; then
    echo "Error: Input folder not found: $input_folder" >&2
    exit 1
fi

mkdir -p "$output_folder"

# ── Helpers ───────────────────────────────────────────────────────────────────

# sanitize_filename <string>
# Strips characters illegal in common filesystems: \ / : * ? " < > |
sanitize_filename() {
    echo "$1" | tr -d '\\/:*?"<>|'
}

# pad_number <n>
# Zero-pads an integer to 3 digits (e.g. 1 -> 001)
pad_number() {
    printf "%03d" "$1"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
file_count=0

# Sort files by name, process only .txt files
while IFS= read -r -d '' file; do

    # Read file — bash reads as UTF-8 when locale is set correctly;
    # strip Windows-style \r so line comparisons work cleanly
    mapfile -t lines < <(sed 's/\r//' "$file")

    [[ ${#lines[@]} -eq 0 ]] && continue

    # ── 1. Extract hymn number and title from first line ──────────────────────
    first_line="${lines[0]}"
    first_line="${first_line#"${first_line%%[![:space:]]*}"}" # ltrim
    first_line="${first_line%"${first_line##*[![:space:]]}"}" # rtrim

    # Split on  <whitespace> [–—-] <whitespace>  (en dash, em dash, or hyphen)
    # Using sed to split into two parts at the first dash-like separator
    num_part=$(echo "$first_line" | sed 's/[[:space:]]*[–—-][[:space:]].*//')
    title_part=$(echo "$first_line" | sed 's/^[^–—-]*[[:space:]]*[–—-][[:space:]]*//')

    # If no separator was found, title_part equals the whole line
    if [[ "$title_part" == "$first_line" ]]; then
        title_part="$first_line"
    fi

    # Extract digits only from the number part
    num_str=$(echo "$num_part" | tr -cd '0-9')
    if [[ "$num_str" =~ ^[0-9]+$ ]]; then
        hymn_number=$((10#$num_str))   # force base-10 (avoids octal for 008, 009)
    else
        hymn_number=0
    fi

    hymn_title="$title_part"

    # Build output filename
    safe_name=$(sanitize_filename "$hymn_title")
    safe_name="${safe_name#"${safe_name%%[![:space:]]*}"}" # ltrim
    safe_name="${safe_name%"${safe_name##*[![:space:]]}"}" # rtrim
    padded=$(pad_number "$hymn_number")
    out_filename="${padded} - ${safe_name}.txt"
    out_path="${output_folder}/${out_filename}"

    # ── 2. Parse sections (skip header lines 0-2, i.e. start at index 3) ─────
    # Sections are stored as parallel arrays:
    #   section_tags[]  — "[Verse]" or "[Chorus]"
    #   section_lines[] — newline-joined content of each section
    section_tags=()
    section_lines=()
    current_tag=""
    current_lines=()

    flush_section() {
        if [[ -n "$current_tag" ]]; then
            section_tags+=("$current_tag")
            # Join current_lines into a single newline-delimited string
            section_lines+=("$(printf '%s\n' "${current_lines[@]+"${current_lines[@]}"}")")
            current_lines=()
        fi
    }

    for (( i=3; i<${#lines[@]}; i++ )); do
        stripped="${lines[$i]}"

        if [[ "$stripped" =~ ^[0-9]+$ ]]; then
            flush_section
            current_tag="[Verse]"
        elif [[ "${stripped,,}" =~ ^(refrain|chorus|kiitikio)$ ]]; then
            flush_section
            current_tag="[Chorus]"
        else
            current_lines+=("$stripped")
        fi
    done
    flush_section

    # ── 3. Extract chorus lines ───────────────────────────────────────────────
    chorus_content=""
    for (( s=0; s<${#section_tags[@]}; s++ )); do
        if [[ "${section_tags[$s]}" == "[Chorus]" ]]; then
            chorus_content="${section_lines[$s]}"
            break
        fi
    done

    # ── 4. Build output ───────────────────────────────────────────────────────
    {
        echo "[Intro]"
        echo "$hymn_title"
        echo "Hymn #${hymn_number}"
        echo ""

        for (( s=0; s<${#section_tags[@]}; s++ )); do
            # Skip original chorus blocks — chorus is injected after each verse
            [[ "${section_tags[$s]}" == "[Chorus]" ]] && continue

            echo "${section_tags[$s]}"
            # Print the section's lines (may be empty string if section had no content)
            if [[ -n "${section_lines[$s]}" ]]; then
                echo "${section_lines[$s]}"
            fi
            echo ""

            if [[ -n "$chorus_content" ]]; then
                echo "[Chorus]"
                echo "$chorus_content"
                echo ""
            fi
        done
    } > "$out_path"

    echo "Written: $out_filename"
    (( file_count++ ))

done < <(find "$input_folder" -maxdepth 1 -name "*.txt" -print0 | sort -z)

echo ""
echo "Done. ${file_count} file(s) processed."
