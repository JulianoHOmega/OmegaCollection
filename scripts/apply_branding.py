"""Run after flutter create to install OmegaCollection icons in native projects."""
from pathlib import Path
import shutil
import re
root=Path(__file__).resolve().parents[1]
source=root/'assets/branding'
win=root/'windows/runner/resources/app_icon.ico'
if win.parent.exists():
 shutil.copyfile(source/'omega_icon.ico',win)
 print('Windows EXE icon resource updated:', win)
cmake=root/'windows/CMakeLists.txt'
if cmake.exists():
 text=cmake.read_text()
 text=re.sub(r'set\(BINARY_NAME\s+[^)]+\)', 'set(BINARY_NAME "OmegaCollection")', text)
 cmake.write_text(text)
runner=root/'windows/runner/main.cpp'
if runner.exists():
 text=runner.read_text().replace('L"omega_collection"', 'L"OmegaCollection"')
 runner.write_text(text)
linux=root/'linux/CMakeLists.txt'
if linux.exists():
 text=linux.read_text()
 text=re.sub(r'set\(BINARY_NAME\s+[^)]+\)', 'set(BINARY_NAME "OmegaCollection")', text)
 linux.write_text(text)
for p in (source/'android').glob('mipmap-*/ic_launcher.png'):
 dest=root/'android/app/src/main/res'/p.parent.name/p.name
 if dest.parent.exists(): shutil.copyfile(p,dest)
manifest=root/'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
 text=manifest.read_text().replace('android:label="omega_collection"','android:label="OmegaCollection"')
 manifest.write_text(text)
print('OmegaCollection branding installed.')
