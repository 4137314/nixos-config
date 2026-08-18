/*
  hub/containers.nix — OCI containers for hub services without a native
  NixOS module.

  Backend
  -------
  Podman (rootful, systemd-managed via `virtualisation.oci-containers`).
  Docker is also available on the box but we prefer podman here — one less
  daemon, better SELinux/user-namespace story, still `docker` CLI-compatible
  via `podman-compose`.

  Networking
  ----------
  Every container binds to 127.0.0.1:<port> and is reverse-proxied by Caddy
  (network/caddy.nix). Ports listed below in the "Port map" section:

      glance          8085   dashboard aggregator
      changedetection 5000   web page change monitor
      karakeep        3005   read-later / bookmarks
      memos           5230   twitter-like notes
      n8n             5678   workflow automation
      firefly         8083   personal finance
      firefly-cron    -      internal
      firefly-db      -      internal PostgreSQL
      ghostfolio      3333   portfolio / investment tracking
      ghostfolio-db   -      internal PostgreSQL
      it-tools        8880   dev utilities
      cyberchef       8880   → 8886 host (data ops)

  State
  -----
  Container volumes live under /var/lib/hub/<service>. Owned by the podman
  subuid range. Covered by restic backup (see modules/backup/restic.nix)
  once /var/lib/hub is added to `paths` (already covered by /home/main? no —
  bump the restic paths list).

  Image pinning
  -------------
  Images are pinned by digest for reproducibility. To bump:
    podman pull ghcr.io/… && podman inspect --format='{{.Digest}}' <image>
  and paste the sha256:… into `image` below.
*/
{ config, ... }:
let
  # Common config for every container: podman backend, host loopback bind,
  # auto-restart on failure, no privileged mode.
  common = {
    autoStart = true;
    login.registry = null;
    extraOptions = [ "--pull=missing" ];
  };

  # Shorthand helper for a container that just needs a port + a mount.
  simple =
    {
      image,
      port,
      dataDir,
      env ? { },
      extraOptions ? [ ],
      cmd ? [ ],
    }:
    common
    // {
      inherit image cmd;
      ports = [ "127.0.0.1:${toString port}:${toString port}" ];
      volumes = [ "${dataDir}:/data" ];
      environment = env;
      extraOptions = common.extraOptions ++ extraOptions;
    };
in
{
  virtualisation.oci-containers = {
    backend = "podman";

    containers = {
      # -------------------------------------------------------------------
      # Glance — dashboard aggregator (RSS, weather, monitors, calendars).
      # -------------------------------------------------------------------
      glance = simple {
        image = "docker.io/glanceapp/glance:latest";
        port = 8085;
        dataDir = "/var/lib/hub/glance";
      };

      # -------------------------------------------------------------------
      # changedetection.io — monitor web pages for changes.
      # -------------------------------------------------------------------
      changedetection = {
        image = "ghcr.io/dgtlmoon/changedetection.io:latest";
        autoStart = true;
        ports = [ "127.0.0.1:5000:5000" ];
        volumes = [ "/var/lib/hub/changedetection:/datastore" ];
        environment = {
          BASE_URL = "https://watch.nixos-hacker-box";
          PORT = "5000";
        };
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Karakeep — modern read-later + bookmarks + notes.
      # -------------------------------------------------------------------
      karakeep = {
        image = "ghcr.io/karakeep-app/karakeep:release";
        autoStart = true;
        ports = [ "127.0.0.1:3005:3000" ];
        volumes = [ "/var/lib/hub/karakeep:/data" ];
        environmentFiles = [ "/var/lib/hub/karakeep/env" ];
        environment = {
          NEXTAUTH_URL = "https://links.nixos-hacker-box";
          DATA_DIR = "/data";
        };
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Memos — twitter-like personal micro-notes.
      # -------------------------------------------------------------------
      memos = simple {
        image = "docker.io/neosmemo/memos:stable";
        port = 5230;
        dataDir = "/var/lib/hub/memos";
        env = {
          TZ = "Europe/Rome";
        };
      };

      # -------------------------------------------------------------------
      # n8n — workflow automation (RSS→ntfy, price alerts, ETL).
      # -------------------------------------------------------------------
      n8n = {
        image = "docker.n8n.io/n8nio/n8n:latest";
        autoStart = true;
        ports = [ "127.0.0.1:5678:5678" ];
        volumes = [ "/var/lib/hub/n8n:/home/node/.n8n" ];
        environment = {
          N8N_HOST = "flow.nixos-hacker-box";
          N8N_PROTOCOL = "https";
          N8N_PORT = "5678";
          WEBHOOK_URL = "https://flow.nixos-hacker-box/";
          GENERIC_TIMEZONE = "Europe/Rome";
          N8N_DIAGNOSTICS_ENABLED = "false";
          N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
        };
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Firefly III — personal finance (accounts, budgets, bills, rules).
      # -------------------------------------------------------------------
      firefly-db = {
        image = "docker.io/library/postgres:16-alpine";
        autoStart = true;
        environment = {
          POSTGRES_USER = "firefly";
          POSTGRES_DB = "firefly";
        };
        environmentFiles = [ "/var/lib/hub/firefly/db.env" ]; # POSTGRES_PASSWORD
        volumes = [ "/var/lib/hub/firefly/db:/var/lib/postgresql/data" ];
        extraOptions = [
          "--pull=missing"
          "--network=hub-firefly"
        ];
      };

      firefly = {
        image = "docker.io/fireflyiii/core:latest";
        autoStart = true;
        dependsOn = [ "firefly-db" ];
        ports = [ "127.0.0.1:8083:8080" ];
        volumes = [ "/var/lib/hub/firefly/upload:/var/www/html/storage/upload" ];
        environmentFiles = [ "/var/lib/hub/firefly/app.env" ]; # APP_KEY, DB pass
        environment = {
          APP_URL = "https://money.nixos-hacker-box";
          TZ = "Europe/Rome";
          DB_CONNECTION = "pgsql";
          DB_HOST = "firefly-db";
          DB_PORT = "5432";
          DB_DATABASE = "firefly";
          DB_USERNAME = "firefly";
          # Only the host loopback proxies to Firefly (Caddy runs on the
          # host at 127.0.0.1). `**` would let any container on the same
          # podman bridge spoof `X-Forwarded-For`.
          TRUSTED_PROXIES = "127.0.0.1";
        };
        extraOptions = [
          "--pull=missing"
          "--network=hub-firefly"
        ];
      };

      # -------------------------------------------------------------------
      # Ghostfolio — investment portfolio tracker (stocks, ETF, crypto).
      # -------------------------------------------------------------------
      ghostfolio-db = {
        image = "docker.io/library/postgres:16-alpine";
        autoStart = true;
        environment = {
          POSTGRES_USER = "ghostfolio";
          POSTGRES_DB = "ghostfolio";
        };
        environmentFiles = [ "/var/lib/hub/ghostfolio/db.env" ];
        volumes = [ "/var/lib/hub/ghostfolio/db:/var/lib/postgresql/data" ];
        extraOptions = [
          "--pull=missing"
          "--network=hub-ghostfolio"
        ];
      };

      ghostfolio-redis = {
        image = "docker.io/library/redis:7-alpine";
        autoStart = true;
        environmentFiles = [ "/var/lib/hub/ghostfolio/redis.env" ];
        extraOptions = [
          "--pull=missing"
          "--network=hub-ghostfolio"
        ];
      };

      ghostfolio = {
        image = "ghcr.io/ghostfolio/ghostfolio:latest";
        autoStart = true;
        dependsOn = [
          "ghostfolio-db"
          "ghostfolio-redis"
        ];
        ports = [ "127.0.0.1:3333:3333" ];
        environmentFiles = [ "/var/lib/hub/ghostfolio/app.env" ];
        environment = {
          NODE_ENV = "production";
          HOST = "0.0.0.0";
          PORT = "3333";
          DATABASE_URL = "postgresql://ghostfolio@ghostfolio-db:5432/ghostfolio";
          REDIS_HOST = "ghostfolio-redis";
        };
        extraOptions = [
          "--pull=missing"
          "--network=hub-ghostfolio"
        ];
      };

      # -------------------------------------------------------------------
      # IT-Tools — a bundle of dev utilities (jwt decoder, hash, colours…)
      # -------------------------------------------------------------------
      it-tools = {
        image = "ghcr.io/corentinth/it-tools:latest";
        autoStart = true;
        ports = [ "127.0.0.1:8880:80" ];
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # CyberChef — "cyber Swiss army knife" for data manipulation.
      # -------------------------------------------------------------------
      cyberchef = {
        image = "ghcr.io/gchq/cyberchef:latest";
        autoStart = true;
        ports = [ "127.0.0.1:8886:80" ];
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # RSS-Bridge — generate RSS feeds from sites that don't expose them
      # (Twitter/X, Instagram, Bandcamp, TikTok, YouTube channels …).
      # Consumed by Miniflux → RSS pipeline.
      # -------------------------------------------------------------------
      rss-bridge = {
        image = "docker.io/rssbridge/rss-bridge:latest";
        autoStart = true;
        ports = [ "127.0.0.1:3062:80" ];
        volumes = [ "/var/lib/hub/rss-bridge:/config" ];
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Firecrawl — LLM-friendly web scraping (markdown + screenshot).
      # Feeds bookmark-summariser + rag-indexer + n8n workflows.
      # -------------------------------------------------------------------
      firecrawl-redis = {
        image = "docker.io/library/redis:7-alpine";
        autoStart = true;
        volumes = [ "/var/lib/hub/firecrawl/redis:/data" ];
        extraOptions = [
          "--pull=missing"
          "--network=hub-firecrawl"
        ];
      };
      firecrawl = {
        image = "ghcr.io/mendableai/firecrawl:latest";
        autoStart = true;
        dependsOn = [ "firecrawl-redis" ];
        ports = [ "127.0.0.1:3002:3002" ];
        environment = {
          NUM_WORKERS_PER_QUEUE = "8";
          PORT = "3002";
          HOST = "0.0.0.0";
          REDIS_URL = "redis://firecrawl-redis:6379";
          REDIS_RATE_LIMIT_URL = "redis://firecrawl-redis:6379";
          # Playwright fallback — comment out to use only fetch-based scraper.
          PLAYWRIGHT_MICROSERVICE_URL = "";
          USE_DB_AUTHENTICATION = "false";
          BULL_AUTH_KEY = "";
          POSTHOG_API_KEY = "";
        };
        extraOptions = [
          "--pull=missing"
          "--network=hub-firecrawl"
        ];
      };

      # -------------------------------------------------------------------
      # SilverBullet — markdown-first PKM with live queries + agents.
      # -------------------------------------------------------------------
      silverbullet = {
        image = "docker.io/zefhemel/silverbullet:latest";
        autoStart = true;
        ports = [ "127.0.0.1:3025:3000" ];
        volumes = [ "/var/lib/hub/silverbullet:/space" ];
        environmentFiles = [ "/var/lib/hub/silverbullet/env" ]; # SB_USER=user:pass
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Kiwix serve — offline Wikipedia + Stack Exchange dumps.
      # Download .zim files into /srv/nas/kiwix beforehand (e.g. via
      # https://download.kiwix.org/zim/wikipedia/).
      # -------------------------------------------------------------------
      kiwix = {
        image = "ghcr.io/kiwix/kiwix-serve:latest";
        autoStart = true;
        ports = [ "127.0.0.1:8087:8080" ];
        volumes = [ "/srv/nas/kiwix:/data:ro" ];
        cmd = [
          "--library"
          "/data/library.xml"
        ];
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # Archivebox — full-page archival (WARC + PDF + screenshot).
      # Sinergico with Karakeep: link → both.
      # -------------------------------------------------------------------
      archivebox = {
        image = "docker.io/archivebox/archivebox:latest";
        autoStart = true;
        ports = [ "127.0.0.1:8088:8000" ];
        volumes = [ "/var/lib/hub/archivebox:/data" ];
        environmentFiles = [ "/var/lib/hub/archivebox/env" ]; # ADMIN_PASSWORD
        environment = {
          ADMIN_USERNAME = "admin";
          ALLOWED_HOSTS = "*";
          PUBLIC_INDEX = "False";
          PUBLIC_SNAPSHOTS = "False";
        };
        cmd = [
          "server"
          "--quick-init"
          "0.0.0.0:8000"
        ];
        extraOptions = [ "--pull=missing" ];
      };

      # -------------------------------------------------------------------
      # OpenBB Platform — investment research (equity/bond/crypto/macro).
      # DISABLED: `docker.io/openbb/openbb:latest` does not exist on
      # Docker Hub (auth denied). Re-enable when the correct image
      # coordinates are known (likely `openbb/platform:*` or a self-built
      # container). Keeping it enabled with a bad image caused an
      # infinite restart loop that blocked `multi-user.target` at boot.
      # -------------------------------------------------------------------
      # openbb = {
      #   image = "openbb/platform:latest";    # ← verify tag before enabling
      #   autoStart = true;
      #   ports = [ "127.0.0.1:6900:6900" ];
      #   volumes = [ "/var/lib/hub/openbb:/root/.openbb_platform" ];
      #   environment = {
      #     OPENBB_API_HOST = "0.0.0.0";
      #     OPENBB_API_PORT = "6900";
      #   };
      #   extraOptions = [ "--pull=missing" ];
      # };

      # -------------------------------------------------------------------
      # Actual Budget — envelope budgeting server.
      # -------------------------------------------------------------------
      actual-budget = {
        image = "docker.io/actualbudget/actual-server:latest";
        autoStart = true;
        ports = [ "127.0.0.1:5006:5006" ];
        volumes = [ "/var/lib/hub/actual:/data" ];
        environment = {
          ACTUAL_UPLOAD_FILE_SYNC_SIZE_LIMIT_MB = "20";
          ACTUAL_UPLOAD_SYNC_ENCRYPTED_FILE_SYNC_SIZE_LIMIT_MB = "50";
        };
        extraOptions = [ "--pull=missing" ];
      };
    };
  };

  # --------------------------------------------------------------------------
  # Podman networks used to isolate multi-container apps (firefly, ghostfolio).
  # Created idempotently at boot; podman network create is a no-op if it exists.
  # --------------------------------------------------------------------------
  systemd.services.hub-networks = {
    description = "Ensure podman networks for hub containers exist";
    wantedBy = [ "multi-user.target" ];
    # Every container that attaches to a `hub-*` network (both the app
    # and its DB / cache sidecar) must wait for this unit; otherwise
    # podman fails with "network hub-<x> not found" during a cold boot.
    before = [
      "podman-firefly.service"
      "podman-firefly-db.service"
      "podman-ghostfolio.service"
      "podman-ghostfolio-db.service"
      "podman-ghostfolio-redis.service"
      "podman-firecrawl.service"
      "podman-firecrawl-redis.service"
    ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${config.virtualisation.podman.package}/bin/podman network create --ignore hub-firefly"
        "${config.virtualisation.podman.package}/bin/podman network create --ignore hub-ghostfolio"
        "${config.virtualisation.podman.package}/bin/podman network create --ignore hub-firecrawl"
      ];
    };
  };

  # Precreate persistent volume directories so podman can bind-mount them.
  systemd.tmpfiles.rules = [
    "d /var/lib/hub                     0755 root root -"
    "d /var/lib/hub/glance              0755 root root -"
    "d /var/lib/hub/changedetection     0755 root root -"
    "d /var/lib/hub/karakeep            0755 root root -"
    "d /var/lib/hub/memos               0755 root root -"
    "d /var/lib/hub/n8n                 0755 root root -"
    "d /var/lib/hub/firefly             0755 root root -"
    "d /var/lib/hub/firefly/db          0700 root root -"
    "d /var/lib/hub/firefly/upload      0755 root root -"
    "d /var/lib/hub/ghostfolio          0755 root root -"
    "d /var/lib/hub/ghostfolio/db       0700 root root -"
    "d /var/lib/hub/rss-bridge          0755 root root -"
    "d /var/lib/hub/firecrawl           0755 root root -"
    "d /var/lib/hub/firecrawl/redis     0755 root root -"
    "d /var/lib/hub/silverbullet        0755 root root -"
    "d /srv/nas/kiwix                   0755 root root -"
    "d /var/lib/hub/archivebox          0755 root root -"
    "d /var/lib/hub/openbb              0755 root root -"
    "d /var/lib/hub/actual              0755 root root -"
  ];
}
