/*
  hub/uptime-kuma.nix — Friendly uptime monitor UI.

  Purpose
  -------
  Complements Prometheus + Grafana: while those aggregate metrics from
  running services, Uptime-Kuma pings services from OUTSIDE (HTTP, TCP,
  DNS, ping, keyword match). If Prometheus goes down, Uptime-Kuma still
  tells you what's up. Also has a much nicer UI for eyeballing status.

  Access
  ------
  http://127.0.0.1:3001 direct, https://status.nixos-hacker-box behind Caddy.

  First-run
  ---------
  Open the URL → create the admin user. Add monitors for:
    - https://nextcloud.nixos-hacker-box
    - https://grafana.nixos-hacker-box
    - https://git.nixos-hacker-box
    - https://photos.nixos-hacker-box
    - https://vault.nixos-hacker-box
  Notification integrations: point at the local ntfy (topic `alerts`) using
  webhook type — Uptime-Kuma sends POST with JSON.
*/
_: {
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
      UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN = "false";
    };
  };
}
