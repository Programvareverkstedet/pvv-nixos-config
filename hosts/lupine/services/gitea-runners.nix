{ config, lib, values, ... }:
{
  nameList = builtins.attrNames (builtins.readDir ../hardware);
}
