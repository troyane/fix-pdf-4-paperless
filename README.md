# Fix PDF for Paperless

A macOS Finder Quick Action that rewrites PDF files using Ghostscript to interpret 
the source PDF and write a clean, standards-compliant file regardless of what the 
original file contained.

Main intent was to overcome `Unsupported mime type application/octet-stream` 
error encountered when uploading PDFs to [Paperless-ngx](https://docs.paperless-ngx.com/).

The issue affects PDFs of various origins (scanners, printers, online tools, etc)
that have a malformed or missing MIME type header. Ghostscript fully rewrites the
file from scratch, producing a standards-compliant PDF.

## Prerequisites

- macOS Ventura 13 or later
- [Homebrew](https://brew.sh)
- Ghostscript — installed automatically by `install.sh`, or manually:

```bash
brew install ghostscript
```

## Install

```bash
git clone https://github.com/troyane/fix-pdf-4-paperless
cd fix-pdf
./install.sh
```

`install.sh` will:

1. Install Ghostscript via Homebrew if it is not already present.
2. Copy `Fix PDF for Paperless.workflow` to `~/Library/Services/`.
3. Flush the macOS services cache and restart Finder.
4. Attempt to enable the Quick Action in macOS Services preferences.

If the automatic Services preference update fails, the workflow is still
installed. Enable it manually in **System Settings → Keyboard → Keyboard
Shortcuts → Services**.

> **First run:** macOS may show a privacy consent dialog asking for Automation
> or file access permissions. Click **Allow** — this is a one-time prompt.

## Usage

1. Select one or more PDF files in Finder.
2. Right-click → **Quick Actions** → **Fix PDF for Paperless**.
3. Wait for the notification: *"PDF regenerated"*.
4. A new file named `original_fixed.pdf` appears next to each source file.
5. Upload the `_fixed` version to Paperless.

The original file is never modified.

## Security

This tool runs Ghostscript against local PDF files. Ghostscript is invoked with
`-dSAFER`, but PDFs can still be a risky input format. Keep Ghostscript updated
and avoid processing files from sources you do not trust.

The installer copies an Automator workflow to `~/Library/Services`, attempts to
enable it in macOS Services preferences, refreshes the Services cache, and may
restart Finder.

## Limitations

- The output PDF may be larger than the original because `/prepress` preserves
  high-quality output and embeds fonts.
- Some interactive PDF features may be flattened or rewritten by Ghostscript.
- Password-protected or damaged PDFs may fail to convert.
- Existing `_fixed.pdf` files are not overwritten; later outputs use suffixes
  such as `_fixed_2.pdf`.

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

## Standalone script

`fix-pdf.sh` can be used directly from the command line:

```bash
./fix-pdf.sh file1.pdf file2.pdf
```

It follows the same logic as the Quick Action (same Ghostscript flags, same
output naming convention).

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

## Portability

To apply on another Mac:

```bash
git clone https://github.com/troyane/fix-pdf-4-paperless
cd fix-pdf
./install.sh
```

No manual Automator configuration required. The entire Quick Action is committed
to the repository as `Fix PDF for Paperless.workflow/`.

## Uninstall

```bash
rm -rf ~/Library/Services/Fix\ PDF\ for\ Paperless.workflow
killall Finder
```

## How it works

Ghostscript flags used:

| Flag | Purpose |
|---|---|
| `-sDEVICE=pdfwrite` | Re-render the PDF through its own writer |
| `-dCompatibilityLevel=1.7` | Output as PDF 1.7 |
| `-dPDFSETTINGS=/prepress` | High-quality output, embed fonts |
| `-dSAFER` | Disable unsafe Ghostscript features |
| `-dNOPAUSE -dBATCH` | Non-interactive batch mode |

These flags cause Ghostscript to interpret the source PDF and write a clean,
standards-compliant file — regardless of what the original file contained.

## License

MIT. See `LICENSE`.
