#!/usr/bin/env python3
"""Check only the deliverable tree; never print candidate secret values."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
errors = []
patterns = [
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{30,}"),
    re.compile("-----BEGIN " + r"(?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"/Users/[^/\s]+/"),
    re.compile(r"/var/folders/"),
]
for path in root.rglob('*'):
    relative = path.relative_to(root)
    if any(part in {'.git', '.build'} for part in relative.parts) or not path.is_file():
        continue
    if 'xcuserdata' in relative.parts or path.suffix in {'.p12', '.p8', '.pem', '.mobileprovision', '.ipa', '.log'}:
        errors.append(f'Excluded artifact: {relative}')
    try:
        text = path.read_text(encoding='utf-8')
    except (UnicodeDecodeError, ValueError):
        continue
    if path.name != 'preflight.py' and any(pattern.search(text) for pattern in patterns):
        errors.append(f'Local path or credential candidate: {relative}')
    if path.name == 'Contents.json':
        for item in json.loads(text).get('images', []):
            if item.get('filename') and not (path.parent / item['filename']).is_file():
                errors.append(f'Missing image: {relative}')
project = (root / 'LiquidChats.xcodeproj/project.pbxproj').read_text()
teams = re.findall(r'DEVELOPMENT_TEAM\s*=\s*([^;]+);', project)
if len(teams) != 2 or any(team.strip() != '""' for team in teams):
    errors.append('Project must have empty development teams in both configurations')
if 'com.example.telegram-party-mode' not in project:
    errors.append('Missing neutral demo bundle identifier')
if (root / 'LICENSE').exists():
    errors.append('Original code must not gain an unapproved license')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: publication tree, signing, image references and credential/path scan')
