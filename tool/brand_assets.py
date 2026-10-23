"""Regenerate launcher assets from the supplied PNG with flutter_launcher_icons.

Run `flutter pub get` first. This wrapper only launches the Dart package;
it never redraws or changes the original artwork.
"""

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys

project_root = Path(__file__).absolute().parents[1]
# Keep an existing ASCII junction when Dart cannot read a Unicode project path.
if not str(project_root).isascii():
    aliases = [Path.home() / '.codex/build/bloom']
    if os.environ.get('LOCALAPPDATA'):
        aliases.append(Path(os.environ['LOCALAPPDATA']) / 'BloomDevelopment/bloom')
    for alias in aliases:
        if alias.is_dir() and alias.samefile(project_root):
            project_root = alias
            break
dart = shutil.which('dart')
if not dart:
    bundled_dart = (
        Path.home() / '.codex/tools/flutter/bin/cache/dart-sdk/bin/dart.exe'
    )
    if bundled_dart.is_file():
        dart = str(bundled_dart)
if not dart:
    sys.exit('Install Flutter and add flutter/bin to PATH, then run flutter pub get.')

# flutter_launcher_icons 0.14.4 matches all ASSETCATALOG_COMPILER_* settings
# when choosing the app icon name. Preserve the unrelated Boolean setting.
project_file = project_root / 'ios/Runner.xcodeproj/project.pbxproj'
symbol_setting = re.compile(
    r'(?m)^\s*ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = [^;]+;'
)
original_settings = symbol_setting.findall(project_file.read_text(encoding='utf-8'))
result = subprocess.call([dart, 'run', 'flutter_launcher_icons'], cwd=project_root)
project_text = project_file.read_text(encoding='utf-8')
if original_settings:
    saved_settings = iter(original_settings)
    project_text = symbol_setting.sub(lambda _: next(saved_settings), project_text)
    project_file.write_text(project_text, encoding='utf-8', newline='\n')
sys.exit(result)
