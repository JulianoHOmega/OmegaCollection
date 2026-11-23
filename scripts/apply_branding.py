"""Run after flutter create to install OmegaCollection icons in native projects."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
source=root/'assets/branding'
win=root/'windows/runner/resources/app_icon.ico'
if win.parent.exists(): shutil.copyfile(source/'omega_icon.ico',win)
for p in (source/'android').glob('mipmap-*/ic_launcher.png'):
 dest=root/'android/app/src/main/res'/p.parent.name/p.name
 if dest.parent.exists(): shutil.copyfile(p,dest)
manifest=root/'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
 text=manifest.read_text().replace('android:label="omega_collection"','android:label="OmegaCollection"')
 manifest.write_text(text)
print('OmegaCollection branding installed.')
