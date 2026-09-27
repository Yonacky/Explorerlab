"""Capture only the foreground Minecraft client image for G0 visual checks.

This diagnostic deliberately returns no world state, coordinates, entity IDs, or
inventory data. It is not a substitute for the controlled effective-tick clock.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import time
from ctypes import wintypes
from pathlib import Path

from PIL import ImageGrab


ROOT = Path(__file__).resolve().parents[1]
USER32 = ctypes.WinDLL("user32", use_last_error=True)
USER32.SetProcessDPIAware()
USER32.GetForegroundWindow.restype = wintypes.HWND
USER32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
USER32.GetWindowTextLengthW.restype = ctypes.c_int
USER32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
USER32.GetWindowTextW.restype = ctypes.c_int
USER32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
USER32.GetClientRect.restype = wintypes.BOOL
USER32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
USER32.ClientToScreen.restype = wintypes.BOOL


def foreground_client() -> tuple[int, tuple[int, int, int, int]]:
    window = USER32.GetForegroundWindow()
    if not window:
        raise RuntimeError("No foreground window")
    length = USER32.GetWindowTextLengthW(window)
    title_buffer = ctypes.create_unicode_buffer(length + 1)
    USER32.GetWindowTextW(window, title_buffer, length + 1)
    if "minecraft" not in title_buffer.value.casefold():
        raise RuntimeError("Foreground window is not Minecraft; bring the game to the front")

    client = wintypes.RECT()
    if not USER32.GetClientRect(window, ctypes.byref(client)):
        raise ctypes.WinError(ctypes.get_last_error())
    if client.right <= 0 or client.bottom <= 0:
        raise RuntimeError("Minecraft client area is empty")
    top_left = wintypes.POINT(0, 0)
    if not USER32.ClientToScreen(window, ctypes.byref(top_left)):
        raise ctypes.WinError(ctypes.get_last_error())
    return window, (top_left.x, top_left.y, top_left.x + client.right, top_left.y + client.bottom)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts" / "screenshots" / "g0.png")
    parser.add_argument("--wait-seconds", type=float, default=10, help="Time to bring Minecraft to the foreground")
    args = parser.parse_args()
    if not 0 <= args.wait_seconds <= 60:
        parser.error("--wait-seconds must be between 0 and 60")
    output = args.output.resolve()
    if not output.is_relative_to(ROOT.resolve()):
        parser.error("output must be inside the project repository")
    deadline = time.monotonic() + args.wait_seconds
    while True:
        try:
            window, bounds = foreground_client()
            break
        except RuntimeError as exc:
            if time.monotonic() >= deadline:
                raise SystemExit(str(exc)) from None
            time.sleep(0.1)
    image = ImageGrab.grab(bbox=bounds, all_screens=True)
    if USER32.GetForegroundWindow() != window:
        raise SystemExit("Foreground window changed during capture; no image was saved")
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG")
    print(json.dumps({
        "image": str(output),
        "width": image.width,
        "height": image.height,
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    }))


if __name__ == "__main__":
    main()
