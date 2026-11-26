import plistlib, shutil, subprocess, os
from pathlib import Path

root  = Path('/Users/niru/.gemini/antigravity/scratch/EdgeBar')
build = root / '.build/debug'
app   = Path('/Users/niru/.gemini/antigravity/scratch/EdgeBar.app')

if app.exists(): 
    shutil.rmtree(app)
(app/'Contents'/'MacOS').mkdir(parents=True)
(app/'Contents'/'Frameworks').mkdir()

shutil.copy2(build / 'EdgeBar', app/'Contents'/'MacOS'/'EdgeBar')
shutil.copytree(build / 'OpenMultitouchSupportXCF.framework',
                app/'Contents'/'Frameworks'/'OpenMultitouchSupportXCF.framework', symlinks=True)

runtime = Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib')
shutil.copy2(runtime, app/'Contents'/'Frameworks'/runtime.name)

with (app/'Contents'/'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleName='EdgeBar', CFBundleDisplayName='EdgeBar',
        CFBundleExecutable='EdgeBar', CFBundleIdentifier='local.edgebar.app',
        CFBundlePackageType='APPL', CFBundleShortVersionString='0.1.0',
        CFBundleVersion='1', LSMinimumSystemVersion='15.0',
        LSUIElement=True, NSHighResolutionCapable=True), f)

subprocess.run(['install_name_tool',
    '-add_rpath', '@executable_path/../Frameworks',
    '-delete_rpath', str(runtime.parent),
    str(app/'Contents'/'MacOS'/'EdgeBar')], check=True)

for item in [app/'Contents'/'Frameworks'/'OpenMultitouchSupportXCF.framework',
             app/'Contents'/'Frameworks'/runtime.name, app]:
    subprocess.run(['codesign','--force','--sign','-', str(item)], check=True)

subprocess.run(['codesign','--verify','--deep','--strict', str(app)], check=True)
print('✅ Packaged:', app)
