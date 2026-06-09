#!/usr/bin/env python3
import plistlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "fix-pdf.sh"
WORKFLOW = ROOT / "Fix PDF for Paperless.workflow" / "Contents" / "document.wflow"


def main() -> int:
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

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
