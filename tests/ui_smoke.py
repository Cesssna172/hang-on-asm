"""Optional Windows integration test. Python 3 standard library only.

Runs the real executable, sends window messages, inspects its own child process,
and saves the actual assembly-rendered framebuffer as PNG images.
"""
import ctypes as ct
from ctypes import wintypes as wt
from pathlib import Path
import os
import shutil
import struct
import subprocess
import time
import zlib
import wave
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "bin" / "hangon.exe"
OUTPUT = ROOT / "build" / "screenshots"
OUTPUT.mkdir(parents=True, exist_ok=True)
NM = shutil.which("nm.exe") or r"C:\msys64\mingw64\bin\nm.exe"
symbols = {}
for line in subprocess.check_output([NM, "-n", str(EXE)], text=True).splitlines():
    parts = line.split()
    if len(parts) == 3:
        symbols[parts[2]] = int(parts[0], 16) - 0x140000000

user = ct.WinDLL("user32", use_last_error=True)
kernel = ct.WinDLL("kernel32", use_last_error=True)
user.FindWindowW.argtypes = [wt.LPCWSTR, wt.LPCWSTR]
user.FindWindowW.restype = wt.HWND
user.GetWindowLongPtrW.argtypes = [wt.HWND, ct.c_int]
user.GetWindowLongPtrW.restype = ct.c_ssize_t
user.SendMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user.SendMessageW.restype = ct.c_ssize_t
user.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user.GetWindowThreadProcessId.argtypes = [wt.HWND, ct.POINTER(wt.DWORD)]
kernel.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
kernel.OpenProcess.restype = wt.HANDLE
kernel.ReadProcessMemory.argtypes = [wt.HANDLE, ct.c_void_p, ct.c_void_p, ct.c_size_t, ct.c_void_p]
kernel.WriteProcessMemory.argtypes = [wt.HANDLE, ct.c_void_p, ct.c_void_p, ct.c_size_t, ct.c_void_p]
kernel.CloseHandle.argtypes = [wt.HANDLE]

# Do not attach to an already-open user's game.
if user.FindWindowW("HangOnAssemblyWindow", None):
    raise SystemExit("Close the running game before this integration test.")

startup = subprocess.STARTUPINFO()
startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
process = subprocess.Popen([str(EXE)], startupinfo=startup)
handle = None
window = None

def wait_for(predicate, seconds=8):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError(f"Game exited unexpectedly: {process.returncode:#x}")
        if predicate():
            return
        time.sleep(0.025)
    raise AssertionError("Integration test timed out")

def read(address, size):
    buffer = ct.create_string_buffer(size)
    if not kernel.ReadProcessMemory(handle, address, buffer, size, None):
        raise ct.WinError(ct.get_last_error())
    return buffer.raw

def value(name):
    return struct.unpack("<i", read(base + symbols[name], 4))[0]

def set_value(name, number):
    buffer = ct.c_int32(number)
    if not kernel.WriteProcessMemory(handle, base + symbols[name], ct.byref(buffer), 4, None):
        raise ct.WinError(ct.get_last_error())

def key(code, down=True):
    user.SendMessageW(window, 0x100 if down else 0x101, code, 0)

def tap(code):
    key(code)
    key(code, False)

def screenshot(name, delay=0.1):
    time.sleep(delay)
    pointer = struct.unpack("<Q", read(base + symbols["pixels"], 8))[0]
    data = read(pointer, 320 * 224 * 4)
    rows = bytearray()
    for y in range(224):
        rows.append(0)
        row = data[y * 1280:(y + 1) * 1280]
        for x in range(0, 1280, 4):
            rows.extend((row[x + 2], row[x + 1], row[x]))
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", 320, 224, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows))
    png += chunk(b"IEND", b"")
    (OUTPUT / name).write_bytes(png)
    return hashlib.sha256(data).hexdigest()

def assert_solid_region(x, y, width, height, color):
    pointer = struct.unpack('<Q', read(base + symbols['pixels'], 8))[0]
    for row in range(y, y+height):
        values = struct.unpack('<'+'I'*width, read(pointer+(row*320+x)*4, width*4))
        assert all((pixel & 0xffffff) == color for pixel in values)

try:
    wait_for(lambda: bool(user.FindWindowW("HangOnAssemblyWindow", None)))
    window = user.FindWindowW("HangOnAssemblyWindow", None)
    pid = wt.DWORD()
    user.GetWindowThreadProcessId(window, ct.byref(pid))
    assert pid.value == process.pid
    base = user.GetWindowLongPtrW(window, -6)
    handle = kernel.OpenProcess(0x0038, False, process.pid)
    if not handle:
        raise ct.WinError(ct.get_last_error())
    wait_for(lambda: value("animation") > 70)
    screenshot("01-title.png")
    assert_solid_region(102, 150, 124, 18, 0)
    assert_solid_region(212, 198, 108, 14, 0)
    tap(13)
    assert value("state") == 1
    screenshot("02-countdown.png")
    key(0x26)
    wait_for(lambda: value("state") == 2)
    wait_for(lambda: value("speed") > 140)
    screenshot("03-race.png")
    if value("audio_ready"):
        assert value("muted") == 0
        pcm = read(base + symbols["wave_buffers"], 6144)
        assert any(pcm), "Engine PCM buffer contains only silence"
        headers = read(base + symbols["wave_headers"], 144)
        assert any(struct.unpack_from("<I", headers, i * 48 + 24)[0] & 0x10 for i in range(3))
        with wave.open(str(OUTPUT / "engine-sample.wav"), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(22050)
            audio.writeframes(pcm)
    tap(ord("P"))
    assert value("state") == 3
    before = value("distance"), value("time_left")
    time.sleep(0.2)
    assert before == (value("distance"), value("time_left"))
    screenshot("04-pause.png")
    tap(ord("P"))
    assert value("state") == 2
    old_x = value("player_x")
    key(0x27)
    time.sleep(0.25)
    key(0x27, False)
    assert value("player_x") > old_x
    old_speed = value("speed")
    key(0x20)
    time.sleep(0.2)
    key(0x20, False)
    assert value("speed") < old_speed
    mute = value("muted")
    tap(ord("M"))
    # Freeze physics while rendering all distinct poses and crash phases.
    set_value('state', 3)
    set_value('distance', 12000)
    set_value('player_x', 0)
    set_value('checkpoint_ticks', 0)
    pose_hashes = set()
    for pose in range(7):
        set_value('lean', (pose-3)*4)
        pose_hashes.add(screenshot(f'pose-{pose}.png'))
        assert value('current_pose') == pose
    assert len(pose_hashes) == 7, 'Some steering poses render identically'
    crash_hashes = set()
    for ticks in [175, 150, 125, 110, 95, 80, 50]:
        set_value('crash_ticks', ticks)
        crash_hashes.add(screenshot(f'crash-{ticks}.png'))
    assert len(crash_hashes) >= 6
    set_value('crash_ticks', 0)
    set_value('lean', 0)
    set_value('state', 2)
    assert value("muted") == (mute ^ 1)
    tap(ord("M"))
    # Capture a real-time steering sequence with the physics running.
    set_value('player_x', 0)
    set_value('speed', 240)
    frame = 0
    capture_times = []
    for code, count in [(0x25, 8), (0x27, 16), (0x25, 8)]:
        key(code)
        for _ in range(count):
            capture_times.append(time.perf_counter())
            screenshot(f'drive-{frame:02d}.png', delay=0.02)
            frame += 1
        key(code, False)
    (OUTPUT/'drive-timing.json').write_text(json.dumps(capture_times))
    # Render every environment and both ending states using debugger-style setup.
    for stage in range(1, 6):
        set_value("stage", stage)
        set_value("distance", (stage - 1) * 360000 + 5000)
        set_value("time_left", 45000)
        set_value("player_x", 0)
        set_value("crash_ticks", 0)
        set_value("checkpoint_ticks", 0)
        screenshot(f"stage-{stage}.png")
    set_value("distance", 1800000)
    wait_for(lambda: value("state") == 4)
    screenshot("05-finish.png")
    tap(ord("R"))
    assert value("state") == 1
    set_value("state", 2)
    set_value('score', 2000000)
    set_value("time_left", 1)
    wait_for(lambda: value("state") == 5)
    screenshot("06-timeout.png")
    wait_for(lambda: value('state') == 6, seconds=7)
    screenshot('07-name-entry.png')
    assert_solid_region(212, 198, 108, 14, 0x7363a4)
    tap(ord('B'))
    assert value('entry_index') == 1
    tap(13)
    assert value('state') == 0
    print("PASS: real window, countdown, input, pause, PCM, mute, 7 distinct lean poses, crash phases, five stages, endings, name entry")
    print(f"Screenshots: {OUTPUT}")
finally:
    if window:
        user.PostMessageW(window, 0x10, 0, 0)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
    if handle:
        kernel.CloseHandle(handle)
