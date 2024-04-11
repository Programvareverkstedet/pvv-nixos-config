final: prev: {
  writers = prev.writers // {
    writeNginxConfig = name: text: final.runCommandLocal name {
      nginxConfig = prev.writers.writeNginxConfig name text;
      nativeBuildInputs = [ final.nginx ];
    } ''
      ln -s "$nginxConfig" "$out"
      nginx -t -c "$out"
    '';
  };
}
