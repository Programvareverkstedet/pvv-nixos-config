{config, lib, pkgs, inputs, values, ...}:

{
  # lfmao
  containers.jokum = {
    interfaces = [ "ens10f1" ];
    # wtf
    path = inputs.self.nixosConfigurations.jokum.config.system.build.toplevel;
  };
}
