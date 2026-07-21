{ config, pkgs, ... }:
{
  sops.secrets."keys/gatus/postgres" = {
    restartUnits = [ "phh-gatus-postgres-checker.service" ];
  };

  sops.templates."gatus-postgres-checker.env" = {
    restartUnits = [ "phh-gatus-postgres-checker.service" ];
    content = ''
      PGHOST=postgres.pvv.ntnu.no
      PGPORT=5432
      PGDATABASE=postgres
      PGUSER=gatus_healthcheck
      PGPASSWORD=${config.sops.placeholder."keys/gatus/postgres"}
    '';
  };

  services.python-http-handlers."gatus-postgres-checker" = {
    listenStreams = [ "127.0.0.1:1338" ];
    libraries = with pkgs.python3Packages; [
      psycopg2
    ];
    serviceConfig = {
      EnvironmentFile = config.sops.templates."gatus-postgres-checker.env".path;
    };
    handler = ''
      import os
      import json
      import psycopg2

      class Handler(BaseHTTPRequestHandler):
          def do_GET(self):
              try:
                  conn = psycopg2.connect(
                      host=os.environ["PGHOST"],
                      port=os.environ.get("PGPORT", "5432"),
                      dbname=os.environ.get("PGDATABASE", "postgres"),
                      user=os.environ["PGUSER"],
                      password=os.environ["PGPASSWORD"],
                      connect_timeout=5,
                  )

                  try:
                      with conn.cursor() as cur:
                          cur.execute("SELECT version();")
                          (version,) = cur.fetchone()

                          cur.execute("SELECT count(*) FROM pg_stat_activity;")
                          (connections,) = cur.fetchone()

                          cur.execute("SELECT count(*) FROM pg_database WHERE NOT datistemplate;")
                          (databases,) = cur.fetchone()
                  finally:
                      conn.close()

                  body = {
                      "ok": True,
                      "version": version,
                      "connections": connections,
                      "databases": databases,
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
