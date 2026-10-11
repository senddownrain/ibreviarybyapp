"""Run beside quiet_book_polish_test.dart; captures native Android frames."""
import re
import subprocess
import time
from pathlib import Path

ADB = r"C:\Users\User\AppData\Local\Android\sdk\platform-tools\adb.exe"
DEVICE = "emulator-5654"


def adb(*args, **kwargs):
    return subprocess.run([ADB, "-s", DEVICE, *args], check=True, **kwargs)


original = adb("shell", "settings", "get", "system", "font_scale",
               capture_output=True, text=True).stdout.strip()
folder = Path("audit-evidence/quiet-book-polish")
folder.mkdir(parents=True, exist_ok=True)
adb("logcat", "-c")
process = subprocess.Popen(
    [ADB, "-s", DEVICE, "logcat", "-v", "raw", "-s", "flutter:I"],
    stdout=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
try:
    for line in process.stdout:
        if "QUIET_BOOK_FONT_SCALE::" in line:
            scale = original if "restore" in line else "2"
            adb("shell", "settings", "put", "system", "font_scale", scale)
        match = re.search(r"QUIET_BOOK_SCREEN::([a-z0-9-]+)", line)
        if match:
            time.sleep(.5)  # Let Android present the already-settled Flutter frame.
            data = adb("exec-out", "screencap", "-p", capture_output=True).stdout
            (folder / (match[1] + "-native.png")).write_bytes(data)
            print(match[1], flush=True)
        if "QUIET_BOOK_CAPTURE_DONE" in line:
            break
finally:
    adb("shell", "settings", "put", "system", "font_scale", original)
    process.terminate()
