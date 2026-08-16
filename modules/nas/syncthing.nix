{ pkgs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# NAS — Sincronizzazione P2P con Syncthing.
#
# Web UI: http://localhost:8384
# Le cartelle da sincronizzare si configurano dalla Web UI al primo avvio.
# ─────────────────────────────────────────────────────────────────────────────
{
  services.syncthing = {
    enable    = true;
    user      = "main";
    dataDir   = "/home/main";
    configDir = "/home/main/.config/syncthing";

    # Apre le porte 22000/tcp e 21027/udp
    openDefaultPorts = true;

    settings = {
      gui.address = "127.0.0.1:8384";
      options = {
        urAccepted    = -1;   # disabilita telemetria
        relaysEnabled = true;
      };
    };
  };

  environment.systemPackages = [ pkgs.syncthing ];
}
