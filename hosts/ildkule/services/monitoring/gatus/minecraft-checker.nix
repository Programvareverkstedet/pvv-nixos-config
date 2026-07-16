{ lib, pkgs, ... }:
{
  services.python-http-handlers."gatus-minecraft-checker" = {
    listenStreams = [ "127.0.0.1:1337" ];
    libraries = with pkgs.python3Packages; [
      mcstatus
    ];
    handler = ''
      import json
      from mcstatus import JavaServer

      class Handler(BaseHTTPRequestHandler):
          def do_GET(self):
              try:
                  mcserver = JavaServer.lookup("minecraft.pvv.ntnu.no")
                  status = mcserver.status()

                  body = {
                      "ok": True,
                      "players": status.players.online,
                      "version": status.version.name,
                      "latency": status.latency,
                  }

                  data = json.dumps(body).encode()

                  self.send_response(200)
                  self.send_header("Content-Type", "application/json")
                  self.send_header("Content-Length", str(len(data)))
                  self.end_headers()
                  self.wfile.write(data)

              except Exception as e:
                  data = json.dumps({"ok": False, "error": str(e)}).encode()
                  self.send_response(500)
                  self.end_headers()
                  self.wfile.write(data)
    '';
  };
}
