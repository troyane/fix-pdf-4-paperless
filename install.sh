#!/bin/bash
set -euo pipefail

WORKFLOW_NAME="Fix PDF for Paperless.workflow"
SERVICES_DIR="$HOME/Library/Services"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Check Ghostscript ──────────────────────────────────────────────────────
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if ! command -v gs &>/dev/null; then
    echo "Ghostscript not found. Attempting to install via Homebrew..."
    if command -v brew &>/dev/null; then
        brew install ghostscript
    else
        osascript -e 'display alert "Homebrew not found" message "Install Homebrew first: https://brew.sh, then re-run install.sh"'
        echo "Error: Homebrew is not installed. Visit https://brew.sh" >&2
        exit 1
    fi
fi

# ── 2. Install Quick Action ───────────────────────────────────────────────────
mkdir -p "$SERVICES_DIR"

DEST="$SERVICES_DIR/$WORKFLOW_NAME"
if [ -d "$DEST" ]; then
    echo "Removing existing installation: $DEST"
    rm -rf "$DEST"
fi

cp -R "$SCRIPT_DIR/$WORKFLOW_NAME" "$DEST"
echo "Installed: $DEST"

# ── 3. Enable Quick Action (NSServicesStatus) ────────────────────────────────
# New services default to hidden; write both key variants macOS uses so the
# action appears in Finder's right-click menu without a manual toggle in
# System Settings → Keyboard → Shortcuts → Services.
python3 - <<'PYEOF'
import subprocess, plistlib, os
prefs = os.path.expanduser("~/Library/Preferences/pbs.plist")
result = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", prefs],
                        capture_output=True)
data = plistlib.loads(result.stdout)
status = data.setdefault("NSServicesStatus", {})
modes = {"ContextMenu": 1, "FinderPreview": 1, "ServicesMenu": 1, "TouchBar": 1}
for key in [
    "(null) - Fix PDF for Paperless - runWorkflowAsService",
    "(null) - Fix_PDF_for_Paperless - runWorkflowAsService",
]:
    status[key] = {"presentation_modes": modes}
data["NSServicesStatus"] = status
with open(prefs, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
PYEOF

# ── 4. Flush services cache ─────────────────────────────────────────────────────
killall pbs 2>/dev/null || true
sleep 1
/System/Library/CoreServices/pbs -update 2>/dev/null || true
killall Finder 2>/dev/null || true

# ── 5. Done ─────────────────────────────────────────────────────────────────────
osascript -e 'display notification "Quick Action installed. Right-click a PDF in Finder → Quick Actions → Fix PDF for Paperless" with title "Fix PDF for Paperless"'
echo "Done. Right-click a PDF in Finder → Quick Actions → \"Fix PDF for Paperless\""
