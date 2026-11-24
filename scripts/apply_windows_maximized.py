"""Patch Flutter-generated Windows runner to maximize natively on startup.
Run after flutter create, before flutter build windows.
"""
from pathlib import Path
import re

runner = Path(__file__).resolve().parents[1] / "windows/runner/win32_window.cpp"
if not runner.is_file():
    raise SystemExit(f"Missing Flutter-generated Windows runner: {runner}")
source = runner.read_text(encoding="utf-8")
# Flutter's generated runner normally uses ShowWindow(window_handle_, command).
pattern = r"ShowWindow\(\s*window_handle_\s*,\s*command\s*\);"
replacement = "ShowWindow(window_handle_, SW_SHOWMAXIMIZED);"
updated, count = re.subn(pattern, replacement, source)
if count != 1:
    raise SystemExit(f"Expected exactly one ShowWindow(window_handle_, command) in {runner}; found {count}. No patch applied.")
runner.write_text(updated, encoding="utf-8")
print("Windows native startup maximization installed (SW_SHOWMAXIMIZED).")
