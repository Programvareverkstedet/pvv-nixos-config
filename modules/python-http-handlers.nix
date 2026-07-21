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

            Only a single `ListenStream` is currently supported by the handler script; if
            you need more than one, you'll have to adjust {option}`handler` accordingly.
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
            "E402" # module level import not at top of file
            "E501" # max line length
            "E704" # multiple statements on one line (def)
            "F811" # redefined while unused
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

            def on_reload():
                # This function is called when the service receives SIGHUP (e.g. via `systemctl reload`).
                # You can use it to clear caches or re-read state. Completely optional
                pass
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
            FileDescriptorName = v.name;
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
            Type = "notify-reload";
            NotifyAccess = "main";
            DynamicUser = true;
            TimeoutStopSec = "35s";

            ExecStart = let
              package = pkgs.writers.writePython3Bin "${v.name}-bin" {
                inherit (v) libraries flakeIgnore;
              } ''
                import os
                import signal
                import socket
                import socketserver
                import threading
                import time
                from http.server import HTTPServer, BaseHTTPRequestHandler

                SOCKET_NAME = "${v.name}"
                SHUTDOWN_TIMEOUT = 30

                def sd_notify(message: str):
                    addr = os.environ.get("NOTIFY_SOCKET")
                    if not addr:
                        return
                    if addr[0] == "@":
                        addr = "\0" + addr[1:]
                    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_CLOEXEC) as sock:
                        sock.connect(addr)
                        sock.sendall(message.encode())

                def sd_listen_fd(name: str) -> int:
                    if os.environ.get("LISTEN_PID") != str(os.getpid()):
                        raise RuntimeError("No sockets were passed to this service by systemd")

                    try:
                        count = int(os.environ.get("LISTEN_FDS", "0"))
                    except ValueError:
                        count = 0

                    raw_names = os.environ.get("LISTEN_FDNAMES")
                    names = raw_names.split(":") if raw_names else []

                    for i in range(count):
                        if i < len(names) and names[i] == name:
                            return 3 + i

                    raise RuntimeError(
                        "No systemd socket named %r was passed to this service; check the "
                        "FileDescriptorName= of the corresponding .socket unit" % name
                    )

                class Server(socketserver.ThreadingMixIn, HTTPServer):
                    daemon_threads = True

                    def server_bind(): pass
                    def server_activate(): pass

                    def __init__(self, *args, **kwargs):
                        super().__init__(*args, **kwargs)
                        self._request_threads = []
                        self._request_threads_lock = threading.Lock()

                    def process_request(self, request, client_address):
                        thread = threading.Thread(
                            target=self.process_request_thread,
                            args=(request, client_address),
                        )
                        thread.daemon = self.daemon_threads
                        with self._request_threads_lock:
                            self._request_threads.append(thread)
                        thread.start()

                    def join_request_threads(self, timeout):
                        deadline = time.monotonic() + timeout
                        with self._request_threads_lock:
                            threads = list(self._request_threads)
                        for thread in threads:
                            thread.join(max(deadline - time.monotonic(), 0))

                def handle_reload(signum, frame):
                    monotonic_usec = time.clock_gettime_ns(time.CLOCK_MONOTONIC) // 1000
                    sd_notify("RELOADING=1\nMONOTONIC_USEC=%d" % monotonic_usec)

                    on_reload = globals().get("on_reload")
                    if callable(on_reload):
                        on_reload()

                    sd_notify("READY=1")

                shutdown_requested = threading.Event()

                def handle_sigterm(signum, frame):
                    sd_notify("STOPPING=1")
                    shutdown_requested.set()

                ${v.handler}

                assert "Handler" in globals(), "You must define a class Handler(BaseHTTPRequestHandler) in the handler code"

                def main():
                    signal.signal(signal.SIGHUP, handle_reload)
                    signal.signal(signal.SIGTERM, handle_sigterm)

                    fd = sd_listen_fd(SOCKET_NAME)

                    httpd = Server(("", 0), Handler, bind_and_activate=False)
                    httpd.socket = socket.socket(fileno=fd)

                    server_thread = threading.Thread(target=httpd.serve_forever, name="http-server", daemon=True)
                    server_thread.start()

                    sd_notify("READY=1")
                    shutdown_requested.wait()

                    deadline = time.monotonic() + SHUTDOWN_TIMEOUT

                    httpd.shutdown()
                    server_thread.join(max(deadline - time.monotonic(), 0))
                    httpd.join_request_threads(max(deadline - time.monotonic(), 0))
                    httpd.server_close()

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
