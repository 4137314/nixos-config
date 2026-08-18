/*
  cloud/nextcloud.nix — Self-hosted Nextcloud with PostgreSQL + Redis.

  Architecture
  ------------
  Nextcloud (PHP-FPM)  ←→  PostgreSQL 16 (local socket)
                       ←→  Redis (in-memory cache, port 6380)
  nginx reverse proxy at http://nixos-hacker-box (port 80)
  Data directory: /srv/nas/nextcloud (Btrfs subvolume, snapshotted)

  Remote access
  -------------
  From inside Tailscale: http://<tailscale-machine-name> (after adding
  the Tailscale IP/hostname to `settings.trusted_domains` below).
  For HTTPS over Tailscale, run `tailscale cert <hostname>` and point
  nginx to the resulting cert/key files.

  First-time setup
  ----------------
  1. Run `nixos-rebuild switch`.
  2. The admin password is read from /etc/nextcloud-admin-pass.
     Create it BEFORE switching:
       echo -n "YourStrongPassword" | sudo tee /etc/nextcloud-admin-pass
       sudo chmod 600 /etc/nextcloud-admin-pass
  3. Open http://nixos-hacker-box in a browser — setup is automatic.
  4. Install the Nextcloud app on Pixel 9a and ThinkPad.
     Enable: Photos (auto-upload), Files, Notes, Contacts, Calendar.

  Nextcloud version
  -----------------
  `pkgs.nextcloud33` targets NC 33.x. When you upgrade NixOS, also bump
  this to the next version (NC enforces sequential major upgrades).
  Run `sudo -u nextcloud nextcloud-occ upgrade` after each bump.
*/
{ pkgs, config, ... }:
{
  # ---------------------------------------------------------------------------
  # Nextcloud
  # ---------------------------------------------------------------------------

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;

    # Hostname used by nginx and Nextcloud's own URL generation.
    # Add more entries (Tailscale IP, etc.) to trusted_domains below.
    hostName = "nixos-hacker-box";
    https = false; # flip to true if you terminate TLS at nginx

    # Data lives on the Btrfs subvolume so snapshots cover it.
    home = "/srv/nas/nextcloud";

    # Automatic PostgreSQL database provisioning.
    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = "/etc/nextcloud-admin-pass";
    };

    settings = {
      default_phone_region = "IT";
      overwriteprotocol = "http"; # change to "https" when using TLS

      # Extend this list after you know your Tailscale IP/hostname:
      #   "100.x.y.z"  or  "nixos-hacker-box.tailXXXXX.ts.net"
      trusted_domains = [
        "nixos-hacker-box"
        "localhost"
        "127.0.0.1"
      ];

      trusted_proxies = [ "127.0.0.1" ];
      # Redis connection is configured automatically by the NixOS module
      # when caching.redis = true (uses unix socket /run/redis-nextcloud/redis.sock).
    };

    caching = {
      apcu = true;
      redis = true;
    };

    # Maximum file upload size (matches nginx client_max_body_size).
    maxUploadSize = "10G";

    # NC cron via systemd timer (default) — never rely on webcron.
    autoUpdateApps.enable = true;

    # PHP tuning for a NAS-backed instance with many small photos + big files.
    phpOptions = {
      "opcache.interned_strings_buffer" = "32";
      "opcache.max_accelerated_files" = "20000";
      "opcache.memory_consumption" = "256";
      "opcache.revalidate_freq" = "60";
      "opcache.jit" = "1255";
      "opcache.jit_buffer_size" = "128M";

      # memory_limit / upload_max_filesize / post_max_size are derived from
      # services.nextcloud.maxUploadSize by the module — do not override here.
      "max_execution_time" = "3600";
      "max_input_time" = "3600";
      "output_buffering" = "0";
    };

    # Recommended extras: image previews (Photos), server-side encryption toggle,
    # first-run apps auto-install.
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit
        calendar
        contacts
        notes
        tasks
        deck
        news
        mail
        previewgenerator
        ;
    };
    extraAppsEnable = true;
  };

  # ---------------------------------------------------------------------------
  # Redis: enabled automatically by the NixOS module when caching.redis = true.
  # PostgreSQL: auto-provisioned by services.nextcloud.database.createLocally.
  # ---------------------------------------------------------------------------

  systemd = {
    # Preview generator — pre-render thumbnails hourly to avoid on-demand
    # PHP-FPM spikes when the Photos gallery is browsed.
    timers.nextcloud-preview-pregen = {
      description = "Nextcloud preview pre-generation";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
    };

    services = {
      nextcloud-preview-pregen = {
        description = "Nextcloud preview generator run";
        after = [ "phpfpm-nextcloud.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "nextcloud";
          ExecStart = "/run/current-system/sw/bin/nextcloud-occ preview:pre-generate";
        };
      };

      # systemd-tmpfiles-setup runs before the Btrfs subvolume is mounted, so
      # the NixOS Nextcloud module's own tmpfiles rules for /srv/nas/nextcloud/
      # config fail silently on first boot. Recreate them after the mount.
      nextcloud-mkdir = {
        description = "Pre-create Nextcloud config dir with correct ownership";
        before = [ "nextcloud-setup.service" ];
        after = [ "srv-nas-nextcloud.mount" ];
        requires = [ "srv-nas-nextcloud.mount" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "/run/current-system/sw/bin/install -d -m 750 -o nextcloud -g nextcloud /srv/nas/nextcloud/config";
          RemainAfterExit = true;
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Nginx: pin the NextCloud vhost to 127.0.0.1:8000 so it does NOT collide
  # with Caddy on port 80. Caddy proxies to 127.0.0.1:8000 for the
  # `nextcloud.nixos-hacker-box` vhost (see modules/network/caddy.nix).
  # No firewall opening — access is always through Caddy on :443.
  # ---------------------------------------------------------------------------
  services.nginx.virtualHosts."nixos-hacker-box".listen = [
    {
      addr = "127.0.0.1";
      port = 8000;
    }
  ];
}
