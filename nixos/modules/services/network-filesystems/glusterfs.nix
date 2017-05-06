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

      preStart = ''
        install -m 0755 -d /var/log/glusterfs
      ''
      # The copying of hooks is due to upstream bug https://bugzilla.redhat.com/show_bug.cgi?id=1452761
      + ''
        mkdir -p /var/lib/glusterd/hooks/
        ${rsync}/bin/rsync -a ${glusterfs}/var/lib/glusterd/hooks/ /var/lib/glusterd/hooks/
      ''
      # `glusterfind` needs dirs that upstream installs at `make install` phase
      # https://github.com/gluster/glusterfs/blob/v3.10.2/tools/glusterfind/Makefile.am#L16-L17
      + ''
        mkdir -p /var/lib/glusterd/glusterfind/.keys
        mkdir -p /var/lib/glusterd/hooks/1/delete/post/
      '';

      serviceConfig = {
        Type="forking";
        PIDFile="/run/glusterd.pid";
        LimitNOFILE=65536;
        ExecStart="${glusterfs}/sbin/glusterd -p /run/glusterd.pid --log-level=${cfg.logLevel} ${toString cfg.extraFlags}";
        KillMode="process";
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
