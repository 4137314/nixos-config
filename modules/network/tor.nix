/*
  network/tor.nix — Tor onion services for hostile-network access.

  Purpose
  -------
  When you're on a network where Tailscale is blocked (hotel WiFi with
  aggressive captive portal, corporate firewall) you can still reach
  the vault via the Tor Browser at http://<random>.onion.

  Exposed onion services
  ----------------------
    vault    → Vaultwarden HTTPS on 127.0.0.1:8222
    git      → Forgejo HTTP on 127.0.0.1:3080
  (add more entries below as needed — one HiddenService block each)

  Persistence
  -----------
  /var/lib/tor/onion/<name>/hostname holds the .onion address. Save it
  in Vaultwarden itself + on paper. It survives reboots.

  Security note
  -------------
  A .onion service is anonymous but NOT private — anyone with the .onion
  URL can reach the service. Vaultwarden's own auth is your protection.
  Do NOT expose services without their own strong auth this way.
*/
_: {
  services.tor = {
    enable = true;
    client.enable = false; # this box is a hidden-service host, not a client
    openFirewall = false; # onion services don't need any inbound port

    relay.onionServices = {
      vault = {
        version = 3;
        map = [
          {
            port = 443; # public port on the .onion address
            target = {
              addr = "127.0.0.1";
              port = 8222;
            };
          }
        ];
      };
      git = {
        version = 3;
        map = [
          {
            port = 80;
            target = {
              addr = "127.0.0.1";
              port = 3080;
            };
          }
        ];
      };
    };
  };
}
