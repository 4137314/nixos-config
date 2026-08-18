/*
  security/suricata.nix — Network Intrusion Detection System.

  Where it listens
  ----------------
  Attached to the physical interface (interface below is a placeholder —
  set it to the real NIC name from `ip link`). Uses AF_PACKET mode so
  no kernel patch or mirror-port SPAN needed.

  What it does
  ------------
  Runs the emerging-threats ETOpen ruleset (~30k rules) against every
  packet, generating eve.json alerts. Promtail scrapes /var/log/suricata/
  into Loki so the existing Grafana + ntfy pipeline picks up findings.

  Overhead
  --------
  ~200-400 MB RAM steady, one CPU core busy on Gbit LAN.

  Rule updates
  ------------
  suricata-update runs weekly (see systemd.timers).

  Turn off gracefully
  -------------------
  Set `services.suricata.enable = false` and rebuild — the module leaves
  no residue.
*/
_: {
  services.suricata = {
    enable = true;

    settings = {
      # Auto-detect the primary Ethernet — adjust after first boot with
      # `ip -o link show` if the NIC name isn't `enp*`.
      "af-packet" = [
        {
          interface = "enp4s0"; # main Ethernet NIC on this box
          cluster-id = 99;
          cluster-type = "cluster_flow";
          defrag = true;
        }
      ];

      "default-log-dir" = "/var/log/suricata";

      "outputs" = [
        {
          "eve-log" = {
            enabled = true;
            filetype = "regular";
            filename = "eve.json";
            types = [
              { alert = { }; }
              {
                http = {
                  extended = true;
                };
              }
              { dns = { }; }
              {
                tls = {
                  extended = true;
                };
              }
              { flow = { }; }
              { ssh = { }; }
            ];
          };
        }
      ];

    };
  };

  # Rule updates are handled by the upstream module's own suricata-update
  # service — we don't need to redeclare it.
}
