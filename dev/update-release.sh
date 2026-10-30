#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# != 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 VERSION (example: $0 0.0.11)" >&2
  exit 2
fi
python="${PYTHON:-$root/dev/.venv/bin/python}"
if [[ ! -x "$python" ]]; then
  echo 'Create dev/.venv and install Markdown; see dev/Readme.md.' >&2
  exit 1
fi
"$python" - "$root" "$1" <<'PY'
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

import markdown

root, version = Path(sys.argv[1]), sys.argv[2]
chrome = os.environ.get('CHROME_BIN') or next(
    (p for name in ('google-chrome', 'chromium', 'chromium-browser')
     if (p := shutil.which(name))), None)
if not chrome:
    sys.exit('Chrome/Chromium is required to render PDFs. Set CHROME_BIN if needed.')
image = f'docker.io/kimc1992/dorarion-core:{version}'
result = subprocess.run(
    ['docker', 'buildx', 'imagetools', 'inspect', image, '--format', '{{json .Manifest}}'],
    check=True, capture_output=True, text=True)
index = json.loads(result.stdout)
digest = index.get('digest', '')
platforms = {(m.get('platform', {}).get('os'), m.get('platform', {}).get('architecture'))
             for m in index.get('manifests', [])
             if m.get('annotations', {}).get('vnd.docker.reference.type') != 'attestation-manifest'}
if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
    sys.exit('Registry did not return a valid shared index digest; nothing changed.')
if not {('linux', 'amd64'), ('linux', 'arm64')} <= platforms:
    sys.exit('Release must contain both linux/amd64 and linux/arm64; nothing changed.')

example = root / '.env.docker.example'
old = re.search(r'^DORARION_IMAGE=docker\.io/kimc1992/dorarion-core:([0-9]+\.[0-9]+\.[0-9]+)@(sha256:[0-9a-f]{64})$',
                example.read_text(), re.MULTILINE)
if not old:
    sys.exit('Cannot identify the current example release pin; nothing changed.')
old_version, old_digest = old.groups()
guides = [('installation-windows-wsl.md', 'en'),
          ('installation-windows-wsl-ko.md', 'ko'),
          ('installation-windows-wsl-zh-cn.md', 'zh-cn')]
paths = [example, root / 'README.md', root / 'tests/check.sh',
         *(root / 'docs' / name for name, _ in guides)]
updated = {}
for path in paths:
    text = path.read_text()
    text = re.sub(r'(?<![\w.])' + re.escape(old_version) + r'(?![\w.])', version, text)
    updated[path] = text.replace(old_digest, digest)

css = '''
@page { size: A4; margin: 15mm; }
body { font: 9.5pt/1.5 "Noto Sans CJK SC", "Noto Sans CJK KR", sans-serif; color: #172332; }
html:lang(ko) body { font-family: "Noto Sans CJK KR", sans-serif; }
p { orphans: 3; widows: 3; }
h1 { font-size: 22pt; color: #173a60; }
h2 { font-size: 15pt; margin-top: 22pt; color: #173a60; }
h3 { font-size: 12pt; }
h1, h2, h3 { break-after: avoid; }
pre { background: #f1f4f7; padding: 9pt; white-space: pre-wrap; overflow-wrap: anywhere;
      font: 8pt/1.45 monospace; break-inside: avoid; }
code { overflow-wrap: anywhere; font-family: monospace; }
blockquote { margin: 10pt 0; border-left: 3pt solid #7496b7; padding-left: 10pt; }
a { color: #145b97; overflow-wrap: anywhere; }
table { border-collapse: collapse; width: 100%; break-inside: avoid; }
td, th { border: 1px solid #cbd3dc; padding: 5pt; }
'''
# Stage all PDFs before changing any release files.
with tempfile.TemporaryDirectory(prefix='release-', dir=root / 'dev') as temporary:
    staging = Path(temporary)
    outputs = []
    for name, language in guides:
        source = root / 'docs' / name
        body = markdown.markdown(updated[source], extensions=['fenced_code', 'tables', 'sane_lists'])
        title = updated[source].splitlines()[0].lstrip('# ')
        document = staging / f'{language}.html'
        document.write_text(f'<!doctype html><html lang="{language}"><meta charset="utf-8">'
                            f'<title>{html.escape(title)}</title><style>{css}</style>{body}</html>')
        pdf = staging / f'dorarion-wsl-docker-install-{language}.pdf'
        command = [chrome, '--headless', '--disable-gpu', '--no-pdf-header-footer',
                   f'--user-data-dir={staging / "chrome"}', f'--print-to-pdf={pdf}', document.as_uri()]
        # Only for environments where the browser sandbox cannot run.
        if os.environ.get('CHROME_NO_SANDBOX') == '1':
            command.insert(1, '--no-sandbox')
        rendered = subprocess.run(command, capture_output=True, text=True, timeout=120)
        if rendered.returncode or not pdf.exists() or not pdf.read_bytes().startswith(b'%PDF-'):
            sys.exit(f'PDF rendering failed for {language}: {rendered.stderr}')
        outputs.append((pdf, root / 'docs/pdf' / pdf.name))
    for path, text in updated.items():
        path.write_text(text)
    for source, destination in outputs:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
print(f'Updated Compose release files and all three PDFs to {image}@{digest}')
print('Registry index includes linux/amd64 and linux/arm64; runtime testing is separate.')
PY
bash "$root/tests/check.sh"
git -C "$root" diff --check
