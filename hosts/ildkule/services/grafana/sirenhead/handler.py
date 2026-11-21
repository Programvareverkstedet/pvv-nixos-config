import html
import http.client
import json
import os
import socket
import uuid
from contextlib import closing
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import quote

TUWUNEL_SOCKET = os.environ["TUWUNEL_SOCKET"]
ROOM_ID = os.environ["ROOM_ID"]
ACCESS_TOKEN = (
    (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "access_token").read_text().strip()
)


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, socket_path: str) -> None:
        super().__init__("localhost", timeout=10)
        self.socket_path = socket_path

    def connect(self) -> None:
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.socket_path)


COLORS = {
    "resolved": "#56a64b",
    "warning": "#f09939",
    "critical": "#f3422e",
}


def format_alert(alert: dict[str, Any]) -> tuple[str, str]:
    labels = alert.get("labels", {})
    name = labels.get("alertname", "unknown alert")
    summary = alert.get("annotations", {}).get("summary", "")
    severity = labels.get("severity", "unknown")
    resolved = alert.get("status") == "resolved"

    tag = "RESOLVED" if resolved else severity.upper()
    color = COLORS.get("resolved" if resolved else severity, "#808080")
    links = ", ".join(
        f'<a href="{html.escape(url)}">{text}</a>'
        for text, url in [
            (
                "📉 How it's going",
                alert.get(
                    "panelURL",
                    alert.get(
                        "dashboardURL", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                    ),
                ),
            ),
            ("📐 Alert Rule", alert.get("generatorURL")),
            ("🔕 Ti still", alert.get("silenceURL")),
        ]
        if url
    )

    plain = f"[{tag}] {name}: {summary}"
    formatted = (
        f'<font color="{color}"><b>[{tag}]</b></font> '
        f"{html.escape(name)}: {html.escape(summary)} ({links})"
    )
    return plain, formatted


def format_message(alert: dict[str, Any]) -> dict[str, str]:
    plain, formatted = zip(
        *map(format_alert, alert.get("alerts", [])),
        strict=True,
    )
    return {
        "msgtype": "m.text",
        "body": "\n".join(["🚨 ALERT 🚨", *plain]),
        "format": "org.matrix.custom.html",
        "formatted_body": "<br>\n".join(["<b>🚨 ALERT 🚨</b>", *formatted]),
    }


def send_alert(alert: dict[str, Any]) -> None:
    path = f"/_matrix/client/v3/rooms/{quote(ROOM_ID, safe='')}/send/m.room.message/{uuid.uuid4().hex}"
    with closing(UnixHTTPConnection(TUWUNEL_SOCKET)) as conn:
        conn.request(
            "PUT",
            path,
            json.dumps(format_message(alert)),
            {
                "Authorization": f"Bearer {ACCESS_TOKEN}",
                "Content-Type": "application/json",
                "X-Forwarded-For": "127.0.0.1",
            },
        )
        response = conn.getresponse()
        data = response.read()

    if response.status != HTTPStatus.OK:
        raise RuntimeError(
            f"PUT {path}: HTTP {response.status}: {data.decode(errors='replace')}"
        )


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        content = self.rfile.read(int(self.headers["Content-Length"]))
        send_alert(json.loads(content))
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()
