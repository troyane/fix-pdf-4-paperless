#!/bin/bash
set -u
#
# fix-pdf -- rewrite PDFs with Ghostscript to fix MIME type issues
#
# USAGE
#   fix-pdf.sh FILE [FILE ...]
#
# DESCRIPTION
#   Rewrites each PDF through Ghostscript's pdfwrite device, producing a
#   standards-compliant file that resolves "Unsupported mime type
#   application/octet-stream" errors in Paperless-ngx and similar tools.
#
#   Each input file produces a new file alongside the original:
#     document.pdf  ->  document_fixed.pdf
#
#   The original is never modified.
#
# REQUIREMENTS
#   Ghostscript (gs):  brew install ghostscript
#
# EXAMPLES
#   ./fix-pdf.sh ~/Downloads/invoice.pdf
#   ./fix-pdf.sh ~/Documents/*.pdf

usage() {
    echo "Usage: $0 FILE [FILE ...]" >&2
}

if [ "$#" -eq 0 ]; then
    usage
    exit 64
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

GS_BIN="$(command -v gs || true)"
if [ -z "$GS_BIN" ]; then
    osascript -e 'display alert "Ghostscript not found" message "Install it with: brew install ghostscript"'
    exit 1
fi

escape_osascript_message() {
    printf '%s' "$1" | sed 's/"/\\"/g'
}

next_output_path() {
    local candidate="$1"
    local dir base stem ext n

    if [ ! -e "$candidate" ]; then
        printf '%s\n' "$candidate"
        return
    fi

    dir="$(dirname "$candidate")"
    base="$(basename "$candidate")"
    stem="${base%.*}"
    ext="${base##*.}"
    n=2

    while [ -e "${dir}/${stem}_${n}.${ext}" ]; do
        n=$((n + 1))
    done

    printf '%s\n' "${dir}/${stem}_${n}.${ext}"
}

had_errors=0

for f in "$@"; do
    if [ ! -f "$f" ]; then
        had_errors=1
        esc_msg="$(escape_osascript_message "$f")"
        osascript -e "display alert \"Input file not found\" message \"$esc_msg\""
        continue
    fi

    dir="$(dirname "$f")"
    base="$(basename "$f")"
    name="${base%.*}"

    case "${base##*.}" in
        pdf|PDF) candidate="${dir}/${name}_fixed.pdf" ;;
        *) candidate="${f}_fixed.pdf" ;;
    esac
    output="$(next_output_path "$candidate")"

    tmplog="$(mktemp /tmp/fix-pdf-XXXXXX.log)"
    "$GS_BIN" \
        -sDEVICE=pdfwrite \
        -dNOPAUSE \
        -dBATCH \
        -dSAFER \
        -dCompatibilityLevel=1.7 \
        -dPDFSETTINGS=/prepress \
        -sOutputFile="$output" \
        "$f" >"$tmplog" 2>&1
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        had_errors=1
        esc_msg="$(tail -n 20 "$tmplog" | sed 's/"/\\"/g')"
        osascript -e "display alert \"Ghostscript error\" message \"$esc_msg\""
    fi
    rm -f "$tmplog"
done

if [ "$had_errors" -eq 0 ]; then
    osascript -e 'display notification "PDF regenerated" with title "Fix PDF for Paperless"' >/dev/null 2>&1 || true
else
    exit 1
fi
