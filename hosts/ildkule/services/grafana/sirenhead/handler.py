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


def format_message(alert: dict[str, Any]) -> dict[str, str]:
    title = alert.get("title", "Grafana Alert!")
    message = alert.get("message", "").strip()
    lines = html.escape(message).replace("\n", "<br>\n")
    return {
        "msgtype": "m.text",
        "body": f"{title}\n\n{message}".strip(),
        "format": "org.matrix.custom.html",
        "formatted_body": f"<h1>{html.escape(title)}</h1>\n{lines}",
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
