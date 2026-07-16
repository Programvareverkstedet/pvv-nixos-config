{ config, options, lib, pkgs, utils, ... }:
let
  cfg = config.services.python-http-handlers;
in
{
  options.services.python-http-handlers = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        enable = lib.mkEnableOption "" // {
          default = true;
          description = "Whether to enable this python HTTP handler.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "phh-${name}";
          defaultText = "phh-<name>";
          description = ''
            The name of this HTTP handler.

            This will be used for the systemd service among other things.
          '';
        };

        listenStreams = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "/run/phh-${name}.socket"
          ];
          defaultText = lib.literalExpression ''
            [
              "/run/phh-<name>.socket"
            ]
          '';
          description = ''
            For each item in this list, a `ListenStream`
            option in the `[Socket]` section will be created.
          '';
        };

        socketConfig = lib.mkOption {
          type = utils.systemdUtils.unitOptions.unitOption;
          default = { };
          description = ''
            Config for the systemd socket's `[Socket]` section.

            See {manpage}`systemd.socket(5)` for details.
          '';
        };

        serviceConfig = lib.mkOption {
          type = utils.systemdUtils.unitOptions.unitOption;
          default = { };
          description = ''
            Config for the systemd service's `[Service]` section.

            See {manpage}`systemd.exec(5)` and {manpage}`systemd.service(5)` for details.
          '';
        };

        enableDefaultHardening = lib.mkEnableOption "" // {
          default = true;
          description = ''
            Whether to enable a set of recommended systemd hardening directives.

            If this breaks the service, you can either override the offending directives
            through {option}`serviceConfig`, or disable this option altogether.
          '';
        };

        libraries = lib.mkOption {
          type = with lib.types; listOf package;
          default = [ ];
          example = lib.literalExpression ''
            with pkgs.python3Packages; [
              matplotlib
              numpy
              pillow
            ]
          '';
          description = ''
            Extra python libraries to make available to the service.
          '';
        };

        flakeIgnore = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "E111" # indentation is not a multiple of four
            "E201" # whitespace after (
            "E202" # whitespace after )
            "E203" # whitespace before :
            "E211" # whitespace before (
            "E251" # unexpected spaces around keyword / parameter equals
            "E301" # expected 1 blank line, found 0
            "E302" # expected 2 blank lines, found 0
            "E303" # too many blank lines
            "E305" # expected 2 blank lines after end of function or class
            "E306" # expected 1 blank line before a nested definition
            "E501" # max line length
            "E704" # multiple statements on one line (def)
          ];
          description = ''
            A list of flake8 rules to ignore while linting the python code.

            An opinionated list of bogus rules (according to module author) is provided as default.
          '';
        };

        handler = lib.mkOption {
          type = lib.types.lines;
          default = ''
            import json

            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = {"ok": True}
                    data = json.dumps(body).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
          '';
          description = ''
            Python code including the HTTP handler for the server.

            You can include as many imports and functions as you'd like here, but you will need
            to at least provide a `class Handler(BaseHTTPRequestHandler)` to handle incoming HTTP requests.
          '';
        };
      };
    }));
  };

  config = {
    systemd.sockets = lib.pipe cfg [
      lib.attrValues
      (lib.filter (v: v.enable))
      (vs: lib.genAttrs' vs (v: {
        inherit (v) name;
        value = {
          wantedBy = [ "sockets.target" ];
          inherit (v) listenStreams;
          socketConfig = {
            Accept = false;
          } // v.socketConfig;
        };
      }))
    ];

    systemd.services = lib.pipe cfg [
      lib.attrValues
      (lib.filter (v: v.enable))
      (vs: lib.genAttrs' vs (v: {
        inherit (v) name;
        value = {
          serviceConfig = {
            Type = "simple";
            DynamicUser = true;

            ExecStart = let
              package = pkgs.writers.writePython3Bin "${v.name}-bin" {
                inherit (v) libraries flakeIgnore;
              } ''
                import socket
                from http.server import HTTPServer, BaseHTTPRequestHandler

                ${v.handler}

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
              '';
            in lib.getExe package;
          } // (lib.optionalAttrs v.enableDefaultHardening {
            AmbientCapabilities = [ "" ];
            CapabilityBoundingSet = [ "" ];
            DeviceAllow = [ "" ];
            LockPersonality = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProcSubset = "pid";
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RemoveIPC = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SocketBindDeny = "any";
            SystemCallArchitectures = "native";
            SystemCallFilter = [
               "@system-service"
               "~@privileged"
               "~@resources"
            ];
            UMask = "0077";
          }) // v.serviceConfig;
        };
      }))
    ];
  };
}
