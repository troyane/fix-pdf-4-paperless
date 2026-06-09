#!/usr/bin/env python3
import os
import plistlib
import subprocess
import sys


def main() -> int:
    prefs = os.path.expanduser("~/Library/Preferences/pbs.plist")
    if not os.path.isfile(prefs):
        print(
            f"Warning: {prefs} not found. Enable the Quick Action manually if it does not appear.",
            file=sys.stderr,
        )
        return 1

    result = subprocess.run(
        ["plutil", "-convert", "xml1", "-o", "-", prefs],
        capture_output=True,
    )
    if result.returncode != 0 or not result.stdout:
        print("Warning: could not read macOS Services preferences.", file=sys.stderr)
        return 1

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
