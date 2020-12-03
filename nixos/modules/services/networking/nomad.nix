{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.nomad;
  format = pkgs.formats.json { };
in
{
  ##### interface
  options = {
    services.nomad = {
      enable = mkEnableOption "Nomad, a distributed, highly available, datacenter-aware scheduler";

      package = mkOption {
        type = types.package;
        default = pkgs.nomad;
        defaultText = "pkgs.nomad";
        description = ''
          The package used for the Nomad agent and CLI.
        '';
      };

      dropPrivileges = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether the nomad agent should be run as a non-root nomad user.
        '';
      };

      settings = mkOption {
        type = format.type;
        default = { };
        description = ''
          Configuration for Nomad. See the <link xlink:href="https://www.nomadproject.io/docs/configuration">documentation</link>
          for supported values.
        '';
      };
    };
  };

  ##### implementation
  config = mkIf cfg.enable {
    environment = {
      etc."nomad.json".source = format.generate "nomad.json" cfg.settings;
      systemPackages = [ cfg.package ];
    };

    systemd.services.nomad = {
      description = "Nomad";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      restartTriggers = [ environment.etc."nomad.json".source ];

      serviceConfig = {
        DynamicUser = cfg.dropPrivileges;
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        ExecStart = "${cfg.package}/bin/nomad agent -config=/etc/nomad.json";
        KillMode = "process";
        KillSignal = "SIGINT";
        LimitNOFILE = 65536;
        LimitNPROC = "infinity";
        OOMScoreAdjust = -1000;
        Restart = "on-failure";
        RestartSec = 2;
        StartLimitBurst = 3;
        StartLimitIntervalSec = 10;
        StateDirectory = "nomad";
        TasksMax = "infinity";
        User = optionalString cfg.dropPrivileges "nomad";
      };
    };
  };
}
