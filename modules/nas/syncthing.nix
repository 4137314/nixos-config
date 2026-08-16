/*
  nas/syncthing.nix — Syncthing peer-to-peer file synchronisation.

  Configuration
  -------------
  User:       main  (service runs as this user, owns synced files)
  Data dir:   /home/main  (root of default folder)
  Config dir: /home/main/.config/syncthing
  Web UI:     http://localhost:8384  (local access only)
  Ports:      22000/tcp (data), 21027/udp (discovery) — opened automatically

  Privacy
  -------
  urAccepted = -1 disables usage-report telemetry to the Syncthing project.

  First run
  ---------
  Open http://localhost:8384 in a browser and add folders/devices via the UI.
  No Nix-managed folder configuration is provided here to keep the NAS setup
  flexible (different clients sync different folder sets).
*/
{ pkgs, ... }:
{
  services.syncthing = {
    enable           = true;
    user             = "main";
    dataDir          = "/home/main";
    configDir        = "/home/main/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      gui.address = "127.0.0.1:8384";
      options = {
        urAccepted    = -1;
        relaysEnabled = true;
      };
    };
  };

  # Provide the syncthing CLI alongside the daemon.
  environment.systemPackages = [ pkgs.syncthing ];
}
