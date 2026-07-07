{ lib, pkgs, ... }:
{
  systemd.sockets."gatus-minecraft-checker" = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:1337" ];
    socketConfig = {
      Accept = false;
    };
  };

  systemd.services."gatus-minecraft-checker" = {
    serviceConfig = {
      ExecStart = lib.getExe (pkgs.writers.writePython3Bin "gatus-minecraft-checker" {
        libraries = with pkgs.python3Packages; [
          # sdnotify
          mcstatus
        ];
        flakeIgnore = [ "E501" "E704" ];
      } ''
        import socket
        import json
        from http.server import HTTPServer, BaseHTTPRequestHandler

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


        class NoBindHTTPServer(HTTPServer):
            def server_bind(): pass
            def server_activate(): pass


        def main():
            httpd = NoBindHTTPServer(
                ("", 0),
                Handler,
                bind_and_activate=False,
            )
            httpd.socket = socket.fromfd(3, socket.AF_INET, socket.SOCK_STREAM)
            httpd.serve_forever()


        if __name__ == '__main__':
            main()
      '');

      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
