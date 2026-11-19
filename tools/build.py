from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib, json

root = Path(__file__).resolve().parents[1]
files = [root / 'LICENSE-InkPlayground', root / 'README-RU.md', root / 'README-EN.md']
for folder in ('bin', 'r6', 'fomod'):
    files.extend(p for p in (root / folder).rglob('*') if p.is_file())
files = sorted(files, key=lambda p: p.relative_to(root).as_posix())
assert len(files) == 7, 'Unexpected payload composition'
assert all(p.suffix in ('.reds', '.lua', '.json', '.xml', '.md') or p.name == 'LICENSE-InkPlayground' for p in files)
assert not any(p.name.startswith('profiles.json') for p in files)
catalog = json.loads((root / 'bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareReflash/catalog.json').read_text(encoding='utf8'))
assert len(catalog) == 36 and all(r.get('labelEN') for r in catalog)
dist = root / 'dist'
dist.mkdir(exist_ok=True)
archive = dist / 'Cyberware-Reflash-0.1.0-alpha.zip'
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for p in files:
        z.write(p, p.relative_to(root).as_posix())
with ZipFile(archive) as z:
    assert z.testzip() is None
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist / (archive.name + '.sha256')).write_text(digest + '  ' + archive.name + '\n', encoding='ascii')
print(archive)
print('SHA256 ' + digest)
