{ config, lib, pkgs, ... }:

with lib;

let
  inherit (pkgs) glusterfs rsync;

  cfg = config.services.glusterfs;

in

{

  ###### interface

  options = {

    services.glusterfs = {

      enable = mkEnableOption "GlusterFS Daemon";

      logLevel = mkOption {
        type = types.enum ["DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL" "TRACE" "NONE"];
        description = "Log level used by the GlusterFS daemon";
        default = "INFO";
      };

      useRpcbind = mkOption {
        type = types.bool;
        description = "Enable use of rpcbind. This is required for Gluster's NFS functionality. You may want to turn it off to reduce the attack surface for DDoS reflection attacks. See https://davelozier.com/glusterfs-and-rpcbind-portmap-ddos-reflection-attacks/ and https://bugzilla.redhat.com/show_bug.cgi?id=1426842 for details.";
        default = true;
      };

      enableGlustereventsd = mkOption {
        type = types.bool;
        description = "Whether to enable the GlusterFS Events Daemon";
        default = true;
      };

      killMode = mkOption {
        type = types.enum ["control-group" "process" "mixed" "none"];
        description = "The systemd KillMode to use for glusterd. glusterd spawns other daemons like gsyncd. If you want these to stop when glusterd is stopped (e.g. to ensure that NixOS config changes are reflected even for these sub-daemons), set this to 'control-group'.";
        default = "process";
      };

      stopKillTimeout = mkOption {
        type = types.str;
        description = "The systemd TimeoutStopSec to use. After this time after having been asked to shut down, glusterd (and depending on the killMode setting also its child processes) are killed by systemd. The default is set low because GlusterFS (as of 3.10) is known to not tell its children like gsyncd to terminate at all.";
        default = "5s";
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        description = "Extra flags passed to the GlusterFS daemon";
        default = [];
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.glusterfs ];

    services.rpcbind.enable = cfg.useRpcbind;

    systemd.services.glusterd = {

      description = "GlusterFS, a clustered file-system server";

      wantedBy = [ "multi-user.target" ];

      requires = lib.optional cfg.useRpcbind "rpcbind.service";
      after = [ "network.target" "local-fs.target" ] ++ lib.optional cfg.useRpcbind [ "rpcbind.service" ];

      # The copying of hooks is due to upstream bug https://bugzilla.redhat.com/show_bug.cgi?id=1452761
      preStart = ''
        install -m 0755 -d /var/log/glusterfs
        mkdir -p /var/lib/glusterd/hooks/
        ${rsync}/bin/rsync -a ${glusterfs}/var/lib/glusterd/hooks/ /var/lib/glusterd/hooks/
      '';

      serviceConfig = {
        Type="forking";
        PIDFile="/run/glusterd.pid";
        LimitNOFILE=65536;
        ExecStart="${glusterfs}/sbin/glusterd -p /run/glusterd.pid --log-level=${cfg.logLevel} ${toString cfg.extraFlags}";
        KillMode=cfg.killMode;
        TimeoutStopSec=cfg.stopKillTimeout;
      };
    };

    systemd.services.glustereventsd = mkIf cfg.enableGlustereventsd {

      description = "Gluster Events Notifier";

      wantedBy = [ "multi-user.target" ];

      after = [ "syslog.target" "network.target" ];

      serviceConfig = {
        Type="simple";
        Environment="PYTHONPATH=${glusterfs}/usr/lib/python2.7/site-packages";
        PIDFile="/run/glustereventsd.pid";
        ExecStart="${glusterfs}/sbin/glustereventsd --pid-file /run/glustereventsd.pid";
        ExecReload="/bin/kill -SIGUSR2 $MAINPID";
        KillMode="control-group";
      };
    };
  };
}
