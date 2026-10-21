"""Build and verify an installable ZIP from the explicit release manifest."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'release-manifest.json').read_text())
addon = manifest['addon']
files = manifest['files']
if len(files) != len(set(files)):
    raise SystemExit('Duplicate manifest path')
for relative in files:
    path = root/relative
    if path.is_symlink() or not path.resolve().is_relative_to((root/addon).resolve()) or not path.is_file():
        raise SystemExit('Invalid release file: '+relative)
actual = {p.relative_to(root).as_posix() for p in (root/addon).rglob('*') if p.is_file()}
if set(files) != actual:
    raise SystemExit('Release manifest does not match the add-on files')
toc = (root/addon/(addon+'.toc')).read_text(encoding='utf-8-sig')
version = re.search(r'^## Version: (.+)$',toc,re.M).group(1).strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-beta\.[0-9]+)?', version):
    raise SystemExit('Unexpected version')
for line in toc.splitlines():
    if line.strip() and not line.startswith('#') and addon+'/'+line.strip().replace('\\','/') not in files:
        raise SystemExit('Missing TOC file: '+line)
dist = root/'dist'
dist.mkdir(exist_ok=True)
archive = dist/(addon+'-'+version+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for relative in sorted(files):
        info = zipfile.ZipInfo(relative, (2026,1,1,0,0,0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        z.writestr(info,(root/relative).read_bytes())
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist()) == set(files)
    for relative in files:
        assert z.read(relative) == (root/relative).read_bytes(), relative
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist/'SHA256SUMS.txt').write_text(checksum+'  '+archive.name+'\n')
print('Verified '+archive.name+' with '+str(len(files))+' files')
print(checksum)
