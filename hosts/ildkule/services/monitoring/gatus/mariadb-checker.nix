{ config, pkgs, ... }:
{
  sops.secrets."keys/gatus/mariadb" = {
    restartUnits = [ "phh-gatus-mariadb-checker.service" ];
  };

  sops.templates."gatus-mariadb-checker.env" = {
    restartUnits = [ "phh-gatus-mariadb-checker.service" ];
    content = ''
      MYSQL_HOST=mysql.pvv.ntnu.no
      MYSQL_PORT=3306
      MYSQL_DATABASE=mysql
      MYSQL_USER=gatus_healthcheck
      MYSQL_PASSWORD=${config.sops.placeholder."keys/gatus/mariadb"}
    '';
  };

  services.python-http-handlers."gatus-mariadb-checker" = {
    listenStreams = [ "127.0.0.1:1339" ];
    libraries = with pkgs.python3Packages; [
      pymysql
    ];
    serviceConfig = {
      EnvironmentFile = config.sops.templates."gatus-mariadb-checker.env".path;
    };
    handler = ''
      import os
      import json
      import pymysql

      class Handler(BaseHTTPRequestHandler):
          def do_GET(self):
              try:
                  conn = pymysql.connect(
                      host=os.environ["MYSQL_HOST"],
                      port=int(os.environ.get("MYSQL_PORT", "3306")),
                      user=os.environ["MYSQL_USER"],
                      password=os.environ["MYSQL_PASSWORD"],
                      database=os.environ.get("MYSQL_DATABASE", "mysql"),
                      connect_timeout=5,
                  )

                  try:
                      with conn.cursor() as cur:
                          cur.execute("SELECT VERSION();")
                          (version,) = cur.fetchone()

                          cur.execute("SHOW STATUS LIKE 'Threads_connected';")
                          (_, connections) = cur.fetchone()

                          cur.execute("SHOW DATABASES;")
                          databases = cur.fetchall()
                  finally:
                      conn.close()

                  body = {
                      "ok": True,
                      "version": version,
                      "connections": int(connections),
                      "databases": len(databases),
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
                  self.send_header("Content-Type", "application/json")
                  self.send_header("Content-Length", str(len(data)))
                  self.end_headers()
                  self.wfile.write(data)
    '';
  };
}
