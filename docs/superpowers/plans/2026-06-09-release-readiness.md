# Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the project for a low-maintenance public `v0.1.0` open source release.

**Architecture:** Keep the project as a small macOS utility: one standalone shell script, one Automator Quick Action, one installer, and lightweight documentation. Reduce release risk by adding a smoke test, documenting the trust model, hardening installer failure paths, and keeping the Automator workflow in sync with the shell script.

**Tech Stack:** Bash, macOS Automator workflow plist files, Python 3 standard library for plist editing, Ghostscript, Homebrew, Markdown.

---

## File Structure

- `fix-pdf.sh`: CLI implementation and source of truth for PDF rewriting behavior.
- `install.sh`: Installs Ghostscript if needed, installs the workflow, enables the Quick Action best-effort, and refreshes Finder services.
- `Fix PDF for Paperless.workflow/Contents/document.wflow`: Automator workflow containing the Quick Action shell command.
- `README.md`: Public installation, usage, security, troubleshooting, and uninstall documentation.
- `LICENSE`: MIT license for public open source use.
- `test/smoke.sh`: Local smoke checks for shell syntax, no-argument CLI behavior, and sample PDF conversion when Ghostscript is available.
- `test/fixtures/minimal.pdf`: Tiny valid PDF fixture used by the smoke test.
- `scripts/enable-workflow-service.py`: Installer helper that updates macOS Services preferences when `python3` is available.
- `scripts/sync-workflow-command.py`: Developer utility that copies `fix-pdf.sh` into the Automator workflow command field so CLI and Quick Action do not drift.

---

### Task 1: Add Release Metadata

**Files:**
- Create: `LICENSE`
- Modify: `README.md`

- [ ] **Step 1: Add MIT license**

Create `LICENSE` with:

```text
MIT License

Copyright (c) 2026 @troyane, https://github.com/troyane/fix-pdf-4-paperless

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Replace placeholder repository URLs**

In `README.md`, replace:

```text
https://github.com/you/fix-pdf.git
```

with:

```text
https://github.com/troyane/fix-pdf-4-paperless
```

- [ ] **Step 3: Add license note to README**

Add this section near the end of `README.md`:

```markdown
## License

MIT. See `LICENSE`.
```

- [ ] **Step 4: Verify**

Run:

```bash
test -f LICENSE
grep -q 'MIT License' LICENSE
grep -q 'https://github.com/troyane/fix-pdf-4-paperless' README.md
```

Expected: all commands exit with status `0`.

- [ ] **Step 5: Commit**

```bash
git add LICENSE README.md
git commit -m "docs: add release metadata"
```

---

### Task 2: Improve CLI Safety and UX

**Files:**
- Modify: `fix-pdf.sh`

- [ ] **Step 1: Add strict mode and usage handling**

Update the start of `fix-pdf.sh` so lines after the header use strict mode, a usage helper, and a no-argument guard:

```bash
#!/bin/bash
set -u
#
# fix-pdf -- rewrite PDFs with Ghostscript to fix MIME type issues
#
# USAGE
#   fix-pdf.sh FILE [FILE ...]
#

usage() {
    echo "Usage: $0 FILE [FILE ...]" >&2
}

if [ "$#" -eq 0 ]; then
    usage
    exit 64
fi
```

Keep the existing description comments after the usage block if desired, but do not leave a path where no input files produces a success notification.

- [ ] **Step 2: Validate input files before running Ghostscript**

Inside the `for f in "$@"; do` loop, add this block before deriving `dir`, `base`, and `name`:

```bash
    if [ ! -f "$f" ]; then
        had_errors=1
        osascript -e "display alert \"Input file not found\" message \"$(printf '%s' "$f" | sed 's/"/\\"/g')\""
        continue
    fi
```

- [ ] **Step 3: Avoid overwriting existing fixed files**

Add a helper before the loop:

```bash
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
```

Then replace the direct `output=...` assignments with a `candidate` assignment followed by:

```bash
    output="$(next_output_path "$candidate")"
```

For `invoice.pdf`, the first output remains `invoice_fixed.pdf`; if it already exists, the next output is `invoice_fixed_2.pdf`.

- [ ] **Step 4: Verify shell syntax**

Run:

```bash
bash -n fix-pdf.sh
```

Expected: no output and exit status `0`.

- [ ] **Step 5: Verify no-argument behavior**

Run:

```bash
./fix-pdf.sh
```

Expected: prints `Usage: ./fix-pdf.sh FILE [FILE ...]` to stderr and exits with status `64`.

- [ ] **Step 6: Commit**

```bash
git add fix-pdf.sh
git commit -m "fix: improve CLI input handling"
```

---

### Task 3: Add Smoke Test

**Files:**
- Create: `test/smoke.sh`
- Create: `test/fixtures/minimal.pdf`

- [ ] **Step 1: Create tiny PDF fixture**

Create `test/fixtures/minimal.pdf` with:

```text
%PDF-1.1
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 72 72] >>
endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
trailer
<< /Root 1 0 R /Size 4 >>
startxref
186
%%EOF
```

- [ ] **Step 2: Create smoke test script**

Create `test/smoke.sh`:

```bash
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
```

- [ ] **Step 3: Make smoke test executable**

Run:

```bash
chmod +x test/smoke.sh
```

- [ ] **Step 4: Run smoke test**

Run:

```bash
./test/smoke.sh
```

Expected: exits with status `0`. On machines without Ghostscript, it prints `Ghostscript not found; skipped conversion smoke test` and still exits with status `0`.

- [ ] **Step 5: Commit**

```bash
git add test/smoke.sh test/fixtures/minimal.pdf
git commit -m "test: add smoke checks"
```

---

### Task 4: Make Installer Safer and More Transparent

**Files:**
- Create: `scripts/enable-workflow-service.py`
- Modify: `install.sh`
- Modify: `README.md`

- [ ] **Step 1: Create `pbs.plist` update helper**

Create `scripts/enable-workflow-service.py`:

```python
#!/usr/bin/env python3
import subprocess, plistlib, os, sys

prefs = os.path.expanduser("~/Library/Preferences/pbs.plist")
if not os.path.isfile(prefs):
    print(f"Warning: {prefs} not found. Enable the Quick Action manually if it does not appear.", file=sys.stderr)
    sys.exit(1)

result = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", prefs],
                        capture_output=True)
if result.returncode != 0 or not result.stdout:
    print("Warning: could not read macOS Services preferences.", file=sys.stderr)
    sys.exit(1)

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

print("Enabled Quick Action in macOS Services preferences.")
```

- [ ] **Step 2: Make helper executable**

Run:

```bash
chmod +x scripts/enable-workflow-service.py
```

- [ ] **Step 3: Make installer call helper best-effort**

Replace the inline Python block in `install.sh` with an explicit `python3` check and a direct helper call:

```bash
if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/scripts/enable-workflow-service.py" || echo "Warning: could not enable Quick Action automatically. Enable it manually in System Settings → Keyboard → Keyboard Shortcuts → Services."
else
    echo "Warning: python3 not found. Enable the Quick Action manually in System Settings → Keyboard → Keyboard Shortcuts → Services."
fi
```

- [ ] **Step 4: Document installer side effects**

In `README.md`, under `install.sh will:`, add that it:

```markdown
4. Attempts to enable the Quick Action in macOS Services preferences.
```

Then add:

```markdown
If the automatic Services preference update fails, the workflow is still installed.
Enable it manually in **System Settings → Keyboard → Keyboard Shortcuts → Services**.
```

- [ ] **Step 5: Verify shell syntax**

Run:

```bash
bash -n install.sh
python3 -m py_compile scripts/enable-workflow-service.py
```

Expected: no output and exit status `0`. If `python3` is not installed on the current machine, skip the `py_compile` command and verify that `install.sh` prints the manual-enable warning path.

- [ ] **Step 6: Commit**

```bash
git add install.sh scripts/enable-workflow-service.py README.md
git commit -m "fix: make installer preference update best-effort"
```

---

### Task 5: Prevent CLI and Workflow Drift

**Files:**
- Create: `scripts/sync-workflow-command.py`
- Modify: `Fix PDF for Paperless.workflow/Contents/document.wflow`
- Modify: `README.md`

- [ ] **Step 1: Create workflow sync script**

Create `scripts/sync-workflow-command.py`:

```python
#!/usr/bin/env python3
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "fix-pdf.sh"
WORKFLOW = ROOT / "Fix PDF for Paperless.workflow" / "Contents" / "document.wflow"

command = SCRIPT.read_text()
if command.startswith("#!/bin/bash\n"):
    command = command.removeprefix("#!/bin/bash\n")

with WORKFLOW.open("rb") as f:
    data = plistlib.load(f)

actions = data.get("actions", [])
if not actions:
    raise SystemExit("Workflow has no actions")

params = actions[0]["action"]["ActionParameters"]
params["COMMAND_STRING"] = command
params["shell"] = "/bin/bash"
params["inputMethod"] = 1

with WORKFLOW.open("wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
```

- [ ] **Step 2: Make sync script executable**

Run:

```bash
chmod +x scripts/sync-workflow-command.py
```

- [ ] **Step 3: Sync workflow**

Run:

```bash
./scripts/sync-workflow-command.py
```

Expected: exits with status `0` and updates `Fix PDF for Paperless.workflow/Contents/document.wflow`.

- [ ] **Step 4: Document workflow sync**

Add this section to `README.md`:

```markdown
## Development

`fix-pdf.sh` is the source of truth for the PDF rewrite logic. After changing it,
sync the Automator workflow:

```bash
./scripts/sync-workflow-command.py
```

Then run:

```bash
./test/smoke.sh
```
```

- [ ] **Step 5: Verify workflow contains current behavior**

Run:

```bash
plutil -p 'Fix PDF for Paperless.workflow/Contents/document.wflow' | grep -q 'next_output_path'
```

Expected: exit status `0`.

- [ ] **Step 6: Commit**

```bash
git add scripts/sync-workflow-command.py 'Fix PDF for Paperless.workflow/Contents/document.wflow' README.md
git commit -m "chore: sync workflow from CLI script"
```

---

### Task 6: Document Security, Limitations, and Troubleshooting

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add security section**

Add:

```markdown
## Security

This tool runs Ghostscript against local PDF files. Ghostscript is invoked with
`-dSAFER`, but PDFs can still be a risky input format. Keep Ghostscript updated
and avoid processing files from sources you do not trust.

The installer copies an Automator workflow to `~/Library/Services`, attempts to
enable it in macOS Services preferences, refreshes the Services cache, and may
restart Finder.
```

- [ ] **Step 2: Add limitations section**

Add:

```markdown
## Limitations

- The output PDF may be larger than the original because `/prepress` preserves
  high-quality output and embeds fonts.
- Some interactive PDF features may be flattened or rewritten by Ghostscript.
- Password-protected or damaged PDFs may fail to convert.
- Existing `_fixed.pdf` files are not overwritten; later outputs use suffixes
  such as `_fixed_2.pdf`.
```

- [ ] **Step 3: Add troubleshooting section**

Add:

```markdown
## Troubleshooting

If the Quick Action does not appear, open **System Settings → Keyboard →
Keyboard Shortcuts → Services** and enable **Fix PDF for Paperless** manually.

If conversion fails, run the script from Terminal to see the Ghostscript error:

```bash
./fix-pdf.sh /path/to/file.pdf
```

If Ghostscript is missing:

```bash
brew install ghostscript
```
```

- [ ] **Step 4: Verify README references key risks**

Run:

```bash
grep -q '## Security' README.md
grep -q '## Limitations' README.md
grep -q '## Troubleshooting' README.md
grep -q -- '-dSAFER' README.md
```

Expected: all commands exit with status `0`.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document security and troubleshooting"
```

---

### Task 7: Final Release Verification

**Files:**
- Modify only if verification exposes defects.

- [ ] **Step 1: Run syntax checks**

Run:

```bash
bash -n fix-pdf.sh
bash -n install.sh
```

Expected: no output and exit status `0`.

- [ ] **Step 2: Run smoke test**

Run:

```bash
./test/smoke.sh
```

Expected: exits with status `0`.

- [ ] **Step 3: Validate workflow plist**

Run:

```bash
plutil -lint 'Fix PDF for Paperless.workflow/Contents/document.wflow'
plutil -lint 'Fix PDF for Paperless.workflow/Contents/Info.plist'
```

Expected: both files report `OK`.

- [ ] **Step 4: Inspect repository state**

Run:

```bash
git status --short
git log --oneline -n 8
```

Expected: `git status --short` is empty after commits; recent commits show the release-readiness changes.

- [ ] **Step 5: Create release tag after manual Finder test**

After manually verifying the Quick Action from Finder on one sample PDF:

```bash
git tag -a v0.1.0 -m "v0.1.0"
```

Expected: tag `v0.1.0` exists locally. Push the tag only after the GitHub repository URL and README are final.

---

## Self-Review

- Spec coverage: covers metadata, README URL, security notes, installer transparency, CLI no-argument behavior, output overwrite avoidance, workflow drift, smoke testing, and final release checks.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation steps remain.
- Scope check: this is one coherent release-readiness pass for a small macOS utility; it does not include packaging, notarization, CI, or a GUI because those are unnecessary for `v0.1.0`.
- Residual decision: the plan uses `https://github.com/troyane/fix-pdf-4-paperless` as the repository URL and `Copyright (c) 2026 @troyane, https://github.com/troyane/fix-pdf-4-paperless` as the license copyright line.
