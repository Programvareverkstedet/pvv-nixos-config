{ config, pkgs, lib, ... }: let
  stockfish = with pkgs.python3Packages; buildPythonPackage rec {
    pname = "stockfish";
    version = "3.28.0";
    disabled = pythonOlder "3.7";

    src = pkgs.fetchFromGitHub {
      owner = "zhelyabuzhsky";
      repo = pname;
      rev = version;
      hash = "sha256-XLgVjLV2QXeTYPjP/lwc0LH850LKJsymFlrAMkAn8HU=";
    };

    format = "setuptools";
    nativeBuildInputs = [
      setuptools
    ];

    propagatedBuildInputs = [
      pytest-runner
    ];

    doCheck = false;
  };

  inputimeout = with pkgs.python3Packages; buildPythonPackage rec {
    pname = "inputimeout";
    version = "1.0.4";
    src = pkgs.fetchFromGitHub {
      owner = "johejo";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-Fh1CaqJOK58nURt4imkhCmZKG2eJlP/Hi10SarUJ+Fs=";
    };

    format = "setuptools";
    nativeBuildInputs = [ setuptools ];

    doCheck = false;
  };

  script = pkgs.writers.writePython3 "chess" {
    libraries = [
      stockfish
      inputimeout   
    ];

    # Fy!
    flakeIgnore = [ "F403" "F405" "E231" "E265" "E302" "E305" "E501" "E722" ];
  } (builtins.replaceStrings [''path="./stockfish"''] [''path="${pkgs.stockfish}/bin/stockfish"''] (builtins.readFile ./chess.py));
in
{
  sops.secrets."keys/wackattack_ctf/flag" = { };

  systemd.sockets."wackattack-ctf-stockfish" = {
    description = "Save some azure credit for the rest of us";
    partOf = [ "wackattack-ctf-stockfish.service" ];
    wantedBy = [ "sockets.target" ];

    socketConfig = {
      ListenStream = "0.0.0.0:9999";
      Accept = true;
    };
  };

  systemd.services."wackattack-ctf-stockfish@" = {
    description = "Save some azure credit for the rest of us";
    after = [ "network.target" ];
    requires = [ "wackattack-ctf-stockfish.socket" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      WorkingDirectory = "%d";
      Restart = "always";
      StandardInput = "socket";
      LoadCredential = "flag.txt:${config.sops.secrets."keys/wackattack_ctf/flag".path}";

      Exec = script;

      # systemd hardening go barr
      ProcSubset = "pid";
      ProtectProc = "invisible";
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      PrivateMounts = true;
      SystemCallArchitectures = "native";
    };
  };
}
