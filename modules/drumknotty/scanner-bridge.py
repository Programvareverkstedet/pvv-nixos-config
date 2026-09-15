import argparse
import os
import signal
import socket
import string
import subprocess
import sys
import threading
import time
import traceback
from pathlib import Path

from evdev import InputDevice
from evdev import ecodes as ec

# --------------------------------------------------------------------- #
#                 Evdev keycode character mappings                      #
# --------------------------------------------------------------------- #

# NOTE: there are more keys to be added here, but we only ever
#       expect the barcode scanner to send digits + enter.

EVDEV_CHARS: dict[int, str] = {}

for code, char in zip(
    range(ec.KEY_1, ec.KEY_0 + 1),
    "1234567890",
    strict=True,
):
    EVDEV_CHARS[code] = char

ENTER_KEYS = {ec.KEY_ENTER, ec.KEY_KPENTER}


# --------------------------------------------------------------------- #
#                          Mini systemd library                         #
# --------------------------------------------------------------------- #

STATUS_INTERVAL_SECONDS = 1

JOURNAL_SOCKET = "/run/systemd/journal/socket"
SYSLOG_IDENTIFIER = "drumknotty-scanner-bridge"
LOG_ERROR = 3
LOG_WARNING = 4
LOG_INFO = 6


def sd_notify(*messages: str) -> None:
    addr = os.environ.get("NOTIFY_SOCKET")
    if not addr:
        return
    if addr.startswith("@"):
        addr = "\0" + addr[1:]
    payload = "\n".join(messages)
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
        sock.connect(addr)
        sock.sendall(payload.encode())


def journal_log(message: str, priority: int = LOG_INFO) -> None:
    payload = (
        f"PRIORITY={priority}\n"
        f"SYSLOG_IDENTIFIER={SYSLOG_IDENTIFIER}\n"
        f"MESSAGE={message}\n"
    )
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
        sock.sendto(payload.encode(), JOURNAL_SOCKET)


scan_count = 0


def status_loop() -> None:
    while True:
        time.sleep(STATUS_INTERVAL_SECONDS)
        sd_notify(f"STATUS=Forwarded {scan_count} scan(s)")


# --------------------------------------------------------------------- #
#                            Rest of the owl                            #
# --------------------------------------------------------------------- #


def inject_text(
    screen_bin: str,
    session: str,
    target: str,
    text: str,
) -> None:
    global scan_count

    result = subprocess.run(
        [
            screen_bin,
            "-S",
            session,
            "-X",
            "at",
            f"{target}%",
            "stuff",
            text,
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    scan_count += 1

    if result.returncode != 0:
        journal_log(
            f"screen -X exited {result.returncode}: {result.stderr.strip()}",
            priority=LOG_ERROR,
        )
    else:
        journal_log(f"{target!r} <- {text.rstrip()!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--device",
        required=True,
        type=Path,
        metavar="PATH",
    )
    parser.add_argument(
        "--screen-bin",
        required=True,
        type=Path,
        metavar="PATH",
    )
    parser.add_argument("--session", required=True, type=str, metavar="NAME")
    parser.add_argument("--target", required=True, type=str, metavar="NAME")
    args = parser.parse_args()

    device = InputDevice(args.device)
    device.grab()
    sd_notify("READY=1")

    def handle_sigterm(_signum, _frame) -> None:
        sd_notify("STOPPING=1")
        device.ungrab()
        sys.exit(0)

    def handle_sighup(_signum, _frame) -> None:
        now = time.clock_gettime(time.CLOCK_MONOTONIC)
        monotonic_usec = int(now * 1_000_000)
        sd_notify(
            "RELOADING=1",
            f"MONOTONIC_USEC={monotonic_usec}",
        )
        device.ungrab()
        os.execv(sys.executable, [sys.executable, *sys.argv])

    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGHUP, handle_sighup)

    threading.Thread(target=status_loop, daemon=True).start()

    line: list[str] = []

    for event in device.read_loop():
        if event.type != ec.EV_KEY:
            continue

        if event.value != 1:  # key up
            continue

        if event.code in ENTER_KEYS:
            text = "".join(line) + "\n"
            line.clear()
            inject_text(args.screen_bin, args.session, args.target, text)
            continue

        char = EVDEV_CHARS.get(event.code)
        if char is not None:
            line.append(char)
        else:
            journal_log(
                f"Unhandled character code: {event.code}",
                priority=LOG_WARNING,
            )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        journal_log(
            f"scanner bridge crashed:\n{traceback.format_exc()}",
            priority=LOG_ERROR,
        )
        sys.exit(1)
