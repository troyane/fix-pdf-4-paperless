#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/fix-pdf-smoke-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$ROOT_DIR"

bash -n fix-pdf.sh
bash -n install.sh

if ./fix-pdf.sh >"$TMP_DIR/no-args.out" 2>"$TMP_DIR/no-args.err"; then
    echo "Expected ./fix-pdf.sh with no args to fail" >&2
    exit 1
fi

grep -q 'Usage:' "$TMP_DIR/no-args.err"

if ! command -v gs >/dev/null 2>&1; then
    echo "Ghostscript not found; skipped conversion smoke test"
    exit 0
fi

cp test/fixtures/minimal.pdf "$TMP_DIR/input.pdf"
./fix-pdf.sh "$TMP_DIR/input.pdf"

test -s "$TMP_DIR/input_fixed.pdf"
file "$TMP_DIR/input_fixed.pdf" | grep -qi 'pdf'

./fix-pdf.sh "$TMP_DIR/input.pdf"
test -s "$TMP_DIR/input_fixed_2.pdf"
