acme-certs: final: prev:
  let
    problematicHosts = [ "matrix.pvv.ntnu.no" "tom.pvv.ntnu.no" ];
    lib = final.lib;
    crt = "${final.path}/nixos/tests/common/acme/server/acme.test.cert.pem";
    key = "${final.path}/nixos/tests/common/acme/server/acme.test.key.pem";
  in {
  writers = prev.writers // {
    writeNginxConfig = name: text: final.runCommandLocal name {
      nginxConfig = prev.writers.writeNginxConfig name text;
      nativeBuildInputs = [ final.bubblewrap ];
    } ''
      cat "$nginxConfig" > "$out"
      substituteInPlace "$out" ${lib.concatMapStrings (host: "--replace ${host} \"localhost\" ") problematicHosts}
      substituteInPlace "$out" --replace ":443" ":4443"
      substituteInPlace "$out" --replace ":80" ":8808"
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
