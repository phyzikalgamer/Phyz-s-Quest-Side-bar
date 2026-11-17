from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent.parent
output = root / 'tools' / 'releases'
output.mkdir(parents=True, exist_ok=True)
for folder, version, docs in [
    (root / 'PhyzQuestBar', '0.4.1', root),
    (root / 'companion' / 'PhyzPersonalGuides', '1.1.0', root / 'companion'),
]:
    archive = output / f'{folder.name}-{version}.zip'
    with ZipFile(archive, 'w', ZIP_DEFLATED) as package:
        for source in folder.rglob('*'):
            if source.is_file():
                assert source.name != 'Import.lua', 'Private imports must never ship'
                package.write(source, f'{folder.name}/{source.relative_to(folder).as_posix()}')
        for name in ['README.md', 'LICENSE']:
            if not (folder / name).exists():
                package.write(docs / name, f'{folder.name}/{name}')
        if folder.name == 'PhyzQuestBar':
            package.write(root / 'integration' / 'PhyzQuestBarBridge.lua', 'PhyzQuestBar/integration/PhyzQuestBarBridge.lua')
    with ZipFile(archive) as package:
        assert package.testzip() is None
        assert f'{folder.name}/{folder.name}.toc' in package.namelist()
        assert all(name.startswith(folder.name + '/') for name in package.namelist())
        assert not any(name.endswith('/Import.lua') for name in package.namelist())
    print(f'Verified {archive.name} ({archive.stat().st_size} bytes)')
