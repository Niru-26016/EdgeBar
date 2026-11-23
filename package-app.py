#!/usr/bin/env python3
"""Build and package a local, ad-hoc-signed Apple Silicon app."""
from pathlib import Path
import plistlib, shutil, subprocess
root = Path(__file__).resolve().parent
subprocess.run(['swift', 'build', '--build-system', 'native'], cwd=root, check=True)
build = root / '.build/debug'
app = root.parent / 'EdgeBar.app'
if app.exists():
    shutil.rmtree(app)
contents = app / 'Contents'
macos = contents / 'MacOS'
frameworks = contents / 'Frameworks'
macos.mkdir(parents=True)
frameworks.mkdir()
shutil.copy2(build / 'EdgeBar', macos / 'EdgeBar')
shutil.copytree(build / 'OpenMultitouchSupportXCF.framework', frameworks / 'OpenMultitouchSupportXCF.framework', symlinks=True)
runtime = Path('/Library/Developer/CommandLineTools/usr/lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib')
shutil.copy2(runtime, frameworks / runtime.name)
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleName='EdgeBar', CFBundleDisplayName='EdgeBar', CFBundleExecutable='EdgeBar', CFBundleIdentifier='local.edgebar.app', CFBundlePackageType='APPL', CFBundleShortVersionString='0.1.0', CFBundleVersion='1', LSMinimumSystemVersion='15.0', LSUIElement=True, NSHighResolutionCapable=True), f)
subprocess.run(['install_name_tool', '-add_rpath', '@executable_path/../Frameworks', '-delete_rpath', '/Library/Developer/CommandLineTools/usr/lib/swift-6.2/macosx', str(macos / 'EdgeBar')], check=True)
for item in [frameworks / 'OpenMultitouchSupportXCF.framework', frameworks / runtime.name, app]:
    subprocess.run(['codesign', '--force', '--sign', '-', str(item)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(app)
