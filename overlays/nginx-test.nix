acme-certs: final: prev:
  let
    lib = final.lib;
    crt = "${final.path}/nixos/tests/common/acme/server/acme.test.cert.pem";
    key = "${final.path}/nixos/tests/common/acme/server/acme.test.key.pem";
  in {
  writers = prev.writers // {
    writeNginxConfig = name: text: final.runCommandLocal name {
      nginxConfig = prev.writers.writeNginxConfig name text;
      nativeBuildInputs = [ final.bubblewrap ];
    } ''
      ln -s "$nginxConfig" "$out"
      set +o pipefail
      bwrap \
        --ro-bind "${crt}" "/etc/certs/nginx.crt" \
        --ro-bind "${key}" "/etc/certs/nginx.key" \
        --ro-bind "/nix" "/nix" \
        --ro-bind "/etc/hosts" "/etc/hosts" \
        --dir "/run/nginx" \
        --dir "/tmp" \
        --dir "/var/log/nginx" \
        ${lib.concatMapStrings (name: "--ro-bind \"${crt}\" \"/var/lib/acme/${name}/fullchain.pem\" \\") acme-certs}
        ${lib.concatMapStrings (name: "--ro-bind \"${key}\" \"/var/lib/acme/${name}/key.pem\" \\") acme-certs}
        ${lib.concatMapStrings (name: "--ro-bind \"${crt}\" \"/var/lib/acme/${name}/chain.pem\" \\") acme-certs}
        ${lib.getExe' final.nginx "nginx"} -t -c "$out" |& grep "syntax is ok"
    '';
  };
}
