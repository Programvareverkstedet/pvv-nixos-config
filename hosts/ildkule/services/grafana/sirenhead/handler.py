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
    annotations = alert.get("annotations", {})
    name = labels.get("alertname", "unknown alert")
    subject = annotations.get("subject")
    severity = labels.get("severity", "unknown")
    resolved = alert.get("status") == "resolved"

    tag = "RESOLVED" if resolved else severity.upper()
    color = COLORS.get("resolved" if resolved else severity, "#808080")
    dashboard_url = next(
        filter(
            None,
            [
                annotations.get("dashboardUrl"),
                alert.get("panelURL"),
                alert.get("dashboardURL"),
            ],
        ),
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    )
    links = ", ".join(
        f'<a href="{html.escape(url)}">{text}</a>'
        for text, url in [
            ("📉 How it's going", dashboard_url),
            ("📐 Alert Rule", alert.get("generatorURL")),
            ("🔕 Ti still", None if resolved else alert.get("silenceURL")),
        ]
        if url
    )

    headline = f"{name}: {subject}" if subject else name
    plain = f"[{tag}] {headline}"
    formatted = (
        f'<font color="{color}"><b>[{tag}]</b></font> '
        f"{html.escape(headline)} ({links})"
    )
    return plain, formatted


def is_critical(alert: dict[str, Any]) -> bool:
    severity = alert.get("labels", {}).get("severity")
    return alert.get("status") == "firing" and severity == "critical"


def format_message(
    alerts: list[dict[str, Any]],
    msgtype: str,
) -> dict[str, str]:
    plain, formatted = map(list, zip(*map(format_alert, alerts), strict=True))
    if msgtype == "m.text":
        plain.insert(0, "🚨 ALERT 🚨")
        formatted.insert(0, "<b>🚨 ALERT 🚨</b>")
    return {
        "msgtype": msgtype,
        "body": "\n".join(plain),
        "format": "org.matrix.custom.html",
        "formatted_body": "<br>\n".join(formatted),
    }


def format_messages(payload: dict[str, Any]) -> list[dict[str, str]]:
    alerts = payload.get("alerts", [])
    critical = [a for a in alerts if is_critical(a)]
    rest = [a for a in alerts if not is_critical(a)]
    return [
        format_message(group, msgtype)
        for group, msgtype in [(rest, "m.notice"), (critical, "m.text")]
        if group
    ]


def send_message(content: dict[str, str]) -> None:
    path = f"/_matrix/client/v3/rooms/{quote(ROOM_ID, safe='')}/send/m.room.message/{uuid.uuid4().hex}"
    with closing(UnixHTTPConnection(TUWUNEL_SOCKET)) as conn:
        conn.request(
            "PUT",
            path,
            json.dumps(content),
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
        for message in format_messages(json.loads(content)):
            send_message(message)
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()
