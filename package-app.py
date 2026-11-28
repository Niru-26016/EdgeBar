#!/usr/bin/env python3
"""Build and package EdgeBar as an ad-hoc-signed macOS .app bundle."""
import argparse
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

TOOLCHAINS = [
    Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib'),
    Path('/Library/Developer/CommandLineTools/usr/lib'),
]


def find_compat_dylib(binary: Path) -> tuple[Path, list[str]]:
    otool_out = subprocess.check_output(['otool', '-l', str(binary)], text=True)
    rpaths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset', otool_out)

    for rpath in rpaths:
        candidate = Path(rpath) / 'libswiftCompatibilitySpan.dylib'
        if candidate.exists():
            return candidate, rpaths

    for base in TOOLCHAINS:
        matches = sorted(base.glob('swift-*/macosx/libswiftCompatibilitySpan.dylib'))
        if matches:
            return matches[-1], rpaths

    raise FileNotFoundError('Could not locate libswiftCompatibilitySpan.dylib in Swift toolchain.')


def main() -> None:
    parser = argparse.ArgumentParser(description='Build and package EdgeBar.app')
    parser.add_argument('--release', action='store_true', help='Build release configuration')
    parser.add_argument('--install', action='store_true', help='Install into /Applications/EdgeBar.app')
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    config = 'release' if args.release else 'debug'
    build_cmd = ['swift', 'build', '--build-system', 'native']
    if args.release:
        build_cmd += ['-c', 'release']
    subprocess.run(build_cmd, cwd=root, check=True)

    build = root / '.build' / config
    app = root.parent / 'EdgeBar.app'
    if app.exists():
        shutil.rmtree(app)

    contents = app / 'Contents'
    macos = contents / 'MacOS'
    frameworks = contents / 'Frameworks'
    macos.mkdir(parents=True)
    frameworks.mkdir()

    binary = macos / 'EdgeBar'
    shutil.copy2(build / 'EdgeBar', binary)
    shutil.copytree(
        build / 'OpenMultitouchSupportXCF.framework',
        frameworks / 'OpenMultitouchSupportXCF.framework',
        symlinks=True,
    )

    runtime, rpaths = find_compat_dylib(binary)
    shutil.copy2(runtime, frameworks / runtime.name)

    with (contents / 'Info.plist').open('wb') as f:
        plistlib.dump(
            {
                'CFBundleName': 'EdgeBar',
                'CFBundleDisplayName': 'EdgeBar',
                'CFBundleExecutable': 'EdgeBar',
                'CFBundleIdentifier': 'local.edgebar.app',
                'CFBundlePackageType': 'APPL',
                'CFBundleShortVersionString': '0.2.0',
                'CFBundleVersion': '2',
                'LSMinimumSystemVersion': '15.0',
                'LSUIElement': True,
                'NSHighResolutionCapable': True,
            },
            f,
        )

    rpath_cmd = ['install_name_tool', '-add_rpath', '@executable_path/../Frameworks']
    for rpath in rpaths:
        if 'swift-' in rpath and Path(rpath).exists():
            rpath_cmd += ['-delete_rpath', rpath]
    rpath_cmd.append(str(binary))
    subprocess.run(rpath_cmd, check=True)

    for item in [frameworks / 'OpenMultitouchSupportXCF.framework', frameworks / runtime.name, app]:
        subprocess.run(['codesign', '--force', '--sign', '-', str(item)], check=True)

    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    print(f'Packaged: {app}')

    if args.install:
        dest = Path('/Applications/EdgeBar.app')
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(app, dest, symlinks=True)
        subprocess.run(['xattr', '-dr', 'com.apple.quarantine', str(dest)], check=False)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(dest)], check=True)
        print(f'Installed: {dest}')


if __name__ == '__main__':
    main()
