{ pkgs, ... }:
{
  users.users.pederbs = {
    isNormalUser = true;
    description = "kul kis";
    extraGroups = [
      "wheel"
      "drift"
      "nix-builder-users"
    ];

    packages = with pkgs; [
      atool
      bat
      edir
      fd
      htop
      jq
      micro
      ncdu
      ripgrep
      sd
      tmux
      wget
      xe
      yq
    ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+qv5MogWwOgctQfQeHxUHF2ij6UA8BR4DLXtZClnw6A1CtOjAtZeAW62C8q9OKaIKDO0hqd2vLBkgEno4smqBDJ2ThwKuXrhiHqJzCkXZqIKKx79mpTo7aRpFgkJ7328Ee+tbqa65coL98WRhLnDg69NDaOfSCmH85/D0kuyTG7mYIMdBtFXB/IU0QC9USCSGcUGSnQAEx8S0vaXL7JP043kfEfeqwsea598qX+LFa2UfGwgLBpiWi4QEfYy6fviz2TFkbRYKQImybidzUHZkljjPupqu8U4dIx/jsJM/vew717xZPCU0ZCho77TIU+bYSitD5mjnzuD7LrAdbFgnhkD2sQlD/hUW40kPVT/Tq3DrpDRKC9tniiTaIQV1Pe0k82XwYrvV/hTl8T1ed6TuzhmUggqowAbJRbaBIa1zI672AFFQM8OBIN59ZlLy3V2RZW4fvQk2/xMRdVBT0W5Upx+9rCbH9LCGWL8gNNA/PRJ0L9Ts6cq8kf4tFhFQQrk= pbsds@bjarte"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCo5/9uHIKhhpVbcLSKslj9wdBiV4YaY/tydTfypNZBMMP2U54640t8JvHHkxCZRur8AqYupellxAqkmKn516Ut0WvfQcNgF7ieI66JHkK1j7kSFHHG1nkJHslwCh2PeYtfx5zHZZq8X9v/UjVGY182BC4BHC5zixmNiUvvc+N24BRT4NwslFmMYVcTdoNBSJXPgte4uUd+FZrAnHQrjYdJVANgI4i1d11mxlDFgJrPJj30KaIDxHAsAWgCEqGLMDO9N1cpGGbXVeXfoGvv+vdCXgbyA8BK7wWwXvy5HlvhpEJo8g84r6uKMMkEf+K1MpTiaNjdu+7/sKD/ZOyDB4RgCBs0DskouWRi+xfxABaKBj6706Z3hpj+GfpuSXrHKgGYXIL4cZHaAlz8GVsN1mUL4eJ12Sk14Od2QUHbzp7TDz5eaWuczPs5W9qXwNDMZcmBBZ3mkt9ZYPvAPRjeLpAKhhA9xPL3hbob5hhAENTWsFRFJEgpm8l362XFIOLHr/M= pbsds@rocm"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpuDBMll1viLKd/wm1lCy9iozyKeXMBHDwhdJOpeRLe pbsds@nord"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm2UFDD+qsnKvlBBZ/nhBqY9yeLewwF/bexD2SUL7E3 pbsds@sopp"
      #"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILocbYCqu63RT2+mE0l+ZWWw9RVHNcydtLXbLklg6oPe pederbs@pvv"
    ];
  };
}
