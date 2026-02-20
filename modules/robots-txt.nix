{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.environment.robots-txt;

  robots-txt-format = {
    type =
      let
        coercedStrToNonEmptyListOfStr = lib.types.coercedTo lib.types.str lib.singleton (
          lib.types.nonEmptyListOf lib.types.str
        );
      in
      lib.types.listOf (
        lib.types.submodule {
          freeformType = lib.types.attrsOf coercedStrToNonEmptyListOfStr;
          options = {
            pre_comment = lib.mkOption {
              description = "Comment to add before the rule";
              type = lib.types.lines;
              default = "";
            };
            post_comment = lib.mkOption {
              description = "Comment to add after the rule";
              type = lib.types.lines;
              default = "";
            };
          };
        }
      );

    generate =
      name: value:
      let
        makeComment =
          comment:
          lib.pipe comment [
            (lib.splitString "\n")
            (lib.map (line: if line == "" then "#" else "# ${line}"))
            (lib.concatStringsSep "\n")
          ];

        ruleToString =
          rule:
          let
            user_agent = rule.User-agent or [ ];
            pre_comment = rule.pre_comment;
            post_comment = rule.post_comment;
            rest = builtins.removeAttrs rule [
              "User-agent"
              "pre_comment"
              "post_comment"
            ];
          in
          lib.concatStringsSep "\n" (
            lib.filter (x: x != null) [
              (if (pre_comment != "") then makeComment pre_comment else null)
              (
                let
                  user-agents = lib.concatMapStringsSep "\n" (value: "User-agent: ${value}") user_agent;
                in
                if user_agent == [ ] then null else user-agents
              )
              (lib.pipe rest [
                (lib.mapAttrsToList (ruleName: map (value: "${ruleName}: ${value}")))
                lib.concatLists
                (lib.concatStringsSep "\n")
              ])
              (if (post_comment != "") then makeComment post_comment else null)
            ]
          );

        content = lib.concatMapStringsSep "\n\n" ruleToString value;
      in
      pkgs.writeText name content;
  };
in
{
  options.environment.robots-txt = lib.mkOption {
    default = { };
    description = ''
      Different instances of robots.txt to use with web services.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "this instance of robots.txt" // {
              default = true;
            };

            path = lib.mkOption {
              description = "The resulting path of the dir containing the robots.txt file";
              type = lib.types.path;
              readOnly = true;
              default = "/etc/robots-txt/${name}";
            };

            rules = lib.mkOption {
              description = "Rules to include in robots.txt";
              default = [ ];
              example = [
                {
                  User-agent = "Googlebot";
                  Disallow = "/no-googlebot";
                }
                {
                  User-agent = "Bingbot";
                  Disallow = [
                    "/no-bingbot"
                    "/no-bingbot2"
                  ];
                }
              ];
              type = robots-txt-format.type;
            };

            virtualHost = lib.mkOption {
              description = "An nginx virtual host to add the robots.txt to";
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        }
      )
    );
  };

  config = {
    environment.etc = lib.mapAttrs' (name: value: {
      name = "robots-txt/${name}/robots.txt";
      value.source = robots-txt-format.generate name value.rules;
    }) cfg;

    services.nginx.virtualHosts = lib.pipe cfg [
      (lib.filterAttrs (_: value: value.virtualHost != null))
      (lib.mapAttrs' (
        name: value: {
          name = value.virtualHost;
          value = {
            locations = {
              "= /robots.txt" = {
                extraConfig = ''
                  add_header Content-Type text/plain;
                '';
                root = cfg.${name}.path;
              };
            };
          };
        }
      ))
    ];
  };
}
