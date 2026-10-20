#!/usr/bin/env python3
"""Check distribution source byte manifest, excluding only this manifest itself."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
manifest=root/'SOURCE_SHA256.json'
obj=json.loads(manifest.read_text())
assert obj['algorithm']=='SHA-256'
expected=obj['files']
actual={}
for file in root.rglob('*'):
    if not file.is_file() or file==manifest: continue
    rel=file.relative_to(root).as_posix()
    if rel.startswith(('.build/','.swiftpm/','.git/','dist/')): continue
    if rel=='__pycache__' or '/__pycache__/' in rel or rel.endswith(('.pyc','.log')): continue
    actual[rel]=hashlib.sha256(file.read_bytes()).hexdigest()
added=sorted(set(actual)-set(expected))
missing=sorted(set(expected)-set(actual))
wrong=sorted(k for k in set(actual)&set(expected) if actual[k]!=expected[k])
if added or missing or wrong or len(actual)!=obj['file_count']:
    print('FAIL: manifest mismatch',{'added':added,'missing':missing,'changed':wrong,'count':len(actual)},file=sys.stderr)
    sys.exit(1)
print(f'PASS: source manifest {len(actual)} files / SHA-256')
