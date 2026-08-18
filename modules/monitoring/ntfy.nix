/*
  monitoring/ntfy.nix — Self-hosted ntfy push-notification server.

  Purpose
  -------
  Terminal endpoint for all alerts fired by Grafana / Prometheus / restic /
  fail2ban. Subscribers (Android / iOS ntfy app, browser, `ntfy sub` CLI)
  receive push notifications for any topic they follow.

  Access
  ------
  Exposed only on localhost — Caddy fronts it with TLS on
  `https://ntfy.nixos-hacker-box/`. From a phone joined to the tailnet,
  subscribe to `https://ntfy.nixos-hacker-box/alerts` (topic `alerts` is
  the default Grafana contact point below).

  Topics used in this flake
  -------------------------
  alerts        Grafana + Prometheus critical alerts
  backup        restic / btrbk success + failure notifications
  security      fail2ban bans, ssh logins, auditd flags
  system        service failures, high temp, disk near full

  Authentication
  --------------
  Anonymous publish is disabled — every publisher must send a bearer token.
  Tokens are provisioned via `ntfy user`. The Grafana / Prometheus /
  systemd units send their token from a secret file (sops in the future,
  /etc/ntfy/token today).

  First-run
  ---------
    1. `sudo ntfy user add --role=admin admin`
    2. `sudo ntfy token add admin` → store in /etc/ntfy/token (400 root)
    3. Add topics ACL: `sudo ntfy access admin '*' rw`
*/
_: {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.nixos-hacker-box";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;

      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";

      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "12h";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
      attachment-total-size-limit = "1G";
      attachment-file-size-limit = "15M";
      attachment-expiry-duration = "3h";

      # Reasonable defaults so a berserk sender can't drown the topic.
      visitor-request-limit-burst = 60;
      visitor-request-limit-replenish = "5s";
      visitor-attachment-total-size-limit = "100M";
    };
  };
}
