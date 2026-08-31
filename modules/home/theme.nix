/*
  home/theme.nix — Central parametric theme.

  Every visual module (hyprland, waybar, kitty, wofi, hyprlock, wallpaper)
  reads its accent colour, opacity, blur and toggle-able ornaments from
  `config.myTheme.*` defined here.

  To change the whole desk visual identity, tweak one attribute in this
  file (or override from another module) and rebuild. Nothing else needs
  to be edited.

  Defaults are compact cyberpunk: cyan + magenta accent, readable blur,
  ~85% window opacity, compact bars and no always-on long ticker banners.

  Every banner is a boolean toggle. Set `myTheme.banners.enable = false`
  to hide the whole feed row, or `myTheme.banners.<name>.enable = false`
  to hide one feed without touching the Waybar module.
*/
{ lib, ... }:
let
  inherit (lib) mkOption types;

  hexColor = types.strMatching "^#[0-9a-fA-F]{6}$";
in
{
  options.myTheme = {
    accent = mkOption {
      type = hexColor;
      default = "#00ffff";
      description = "Primary neon accent (borders, active states, focus rings).";
    };

    accentSecondary = mkOption {
      type = hexColor;
      default = "#ff00ff";
      description = "Secondary accent for gradients (border sweep, ticker highlights).";
    };

    warn = mkOption {
      type = hexColor;
      default = "#ffb000";
      description = "Warning colour (rate limits, degraded services).";
    };

    danger = mkOption {
      type = hexColor;
      default = "#ff3355";
      description = "Danger colour (critical temp, red 24h change).";
    };

    good = mkOption {
      type = hexColor;
      default = "#00ff88";
      description = "Positive colour (green 24h change, healthy service).";
    };

    base = mkOption {
      type = hexColor;
      default = "#07090f";
      description = "Deep background used for opaque panels.";
    };

    surface = mkOption {
      type = hexColor;
      default = "#101622";
      description = "Panel surface (waybar, wofi background).";
    };

    fg = mkOption {
      type = hexColor;
      default = "#d7e2ff";
      description = "Primary foreground text.";
    };

    fgDim = mkOption {
      type = hexColor;
      default = "#768096";
      description = "Dimmed foreground (inactive workspace, hint text).";
    };

    opacity = {
      active = mkOption {
        type = types.float;
        default = 0.88;
        description = "Focused window opacity (0.0-1.0).";
      };
      inactive = mkOption {
        type = types.float;
        default = 0.75;
        description = "Unfocused window opacity.";
      };
      terminal = mkOption {
        type = types.float;
        default = 0.82;
        description = "Kitty terminal background opacity.";
      };
      bar = mkOption {
        type = types.float;
        default = 0.72;
        description = "Waybar background opacity.";
      };
      launcher = mkOption {
        type = types.float;
        default = 0.85;
        description = "Wofi launcher background opacity.";
      };
    };

    blur = {
      size = mkOption {
        type = types.int;
        default = 10;
        description = "Hyprland blur kernel size.";
      };
      passes = mkOption {
        type = types.int;
        default = 4;
        description = "Hyprland blur passes (higher = softer, more GPU).";
      };
    };

    border = {
      size = mkOption {
        type = types.int;
        default = 2;
        description = "Window border thickness in px.";
      };
      rounding = mkOption {
        type = types.int;
        default = 6;
        description = "Window corner radius in px (0 = sharp cyberpunk).";
      };
    };

    bars = {
      ops = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the lower operations/security Waybar.";
        };
        width = mkOption {
          type = types.int;
          default = 0;
          description = "Fixed width of the operations/security Waybar. 0 = fill the output (full-width).";
        };
        height = mkOption {
          type = types.int;
          default = 30;
          description = "Height of the lower operations/security Waybar.";
        };
        position = mkOption {
          type = types.enum [
            "bottom"
            "top"
          ];
          default = "bottom";
          description = "Screen edge for the operations/security Waybar.";
        };
      };
      spine = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the vertical engineering Waybar spine.";
        };
        width = mkOption {
          type = types.int;
          default = 90;
          description = "Width of the vertical engineering Waybar spine.";
        };
        position = mkOption {
          type = types.enum [
            "left"
            "right"
          ];
          default = "right";
          description = "Screen edge for the engineering Waybar spine.";
        };
      };
      hud = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the square command/widget HUD Waybar.";
        };
        width = mkOption {
          type = types.int;
          default = 90;
          description = "Width of the square command/widget HUD.";
        };
        tileSize = mkOption {
          type = types.int;
          default = 40;
          description = "Tile height for HUD widgets (width fills the bar).";
        };
        position = mkOption {
          type = types.enum [
            "left"
            "right"
          ];
          default = "left";
          description = "Screen edge for the square command/widget HUD.";
        };
        marginTop = mkOption {
          type = types.int;
          default = 40;
          description = "Top margin for the square command/widget HUD.";
        };
      };
    };

    modes = {
      cycle = mkOption {
        type = types.listOf (
          types.enum [
            "study"
            "dev"
            "hack"
            "work"
            "personal"
            "focus"
            "night"
            "server"
            "recon"
          ]
        );
        default = [
          "study"
          "dev"
          "hack"
          "work"
          "personal"
        ];
        description = "Runtime hb-mode cycle used by the UI controls.";
      };
    };

    widgets = {
      mode = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show runtime hb-mode state and controls.";
        };
        interval = mkOption {
          type = types.int;
          default = 3;
          description = "Refresh interval in seconds.";
        };
      };
      matrix = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show a compact rotating hex signature widget.";
        };
        interval = mkOption {
          type = types.int;
          default = 5;
          description = "Refresh interval in seconds.";
        };
      };
      keyboard = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the active Hyprland keyboard layout.";
        };
        interval = mkOption {
          type = types.int;
          default = 2;
          description = "Refresh interval in seconds.";
        };
      };
      news = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show a square news API widget in the HUD.";
        };
        interval = mkOption {
          type = types.int;
          default = 300;
          description = "Refresh interval in seconds.";
        };
      };
      pi = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the Pi pull-up agent launcher in the HUD.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      configIntel = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show /etc/nixos configuration intelligence in the HUD.";
        };
        interval = mkOption {
          type = types.int;
          default = 20;
          description = "Refresh interval in seconds.";
        };
      };
      agentIntel = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show autonomous agent and observatory state in the HUD.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      serviceIntel = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show compact critical service health in the HUD.";
        };
        interval = mkOption {
          type = types.int;
          default = 20;
          description = "Refresh interval in seconds.";
        };
      };
      localIp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show the primary non-container IPv4 address.";
        };
        interval = mkOption {
          type = types.int;
          default = 15;
          description = "Refresh interval in seconds.";
        };
      };
      services = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show critical service health counts.";
        };
        interval = mkOption {
          type = types.int;
          default = 20;
          description = "Refresh interval in seconds.";
        };
      };
      ssh = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show established SSH session count.";
        };
        interval = mkOption {
          type = types.int;
          default = 10;
          description = "Refresh interval in seconds.";
        };
      };
      fail2ban = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show recent SSH authentication failure pressure.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      tailscale = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Tailscale service and tunnel state.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      tor = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Tor onion-service host state.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      identity = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Show operator/host identity in the engineering spine.";
        };
        interval = mkOption {
          type = types.int;
          default = 3600;
          description = "Refresh interval in seconds.";
        };
      };
      flake = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show /etc/nixos git branch and dirty state.";
        };
        interval = mkOption {
          type = types.int;
          default = 15;
          description = "Refresh interval in seconds.";
        };
      };
      generation = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show current NixOS generation drift state.";
        };
        interval = mkOption {
          type = types.int;
          default = 60;
          description = "Refresh interval in seconds.";
        };
      };
      store = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Nix store filesystem pressure.";
        };
        interval = mkOption {
          type = types.int;
          default = 60;
          description = "Refresh interval in seconds.";
        };
      };
      ports = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show listening TCP port count.";
        };
        interval = mkOption {
          type = types.int;
          default = 15;
          description = "Refresh interval in seconds.";
        };
      };
      containers = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Docker and Podman running container count.";
        };
        interval = mkOption {
          type = types.int;
          default = 20;
          description = "Refresh interval in seconds.";
        };
      };
      virt = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show libvirt VM state.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      backup = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show restic backup timer/service health.";
        };
        interval = mkOption {
          type = types.int;
          default = 60;
          description = "Refresh interval in seconds.";
        };
      };
      nas = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Samba and Syncthing service health.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      observability = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Prometheus, Grafana, Loki and ntfy health.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      ai = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show local AI service health.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      cloud = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show Nextcloud, Forgejo and Caddy-facing cloud health.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      hub = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show personal hub service health.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
      agents = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show observatory/agent timer state.";
        };
        interval = mkOption {
          type = types.int;
          default = 60;
          description = "Refresh interval in seconds.";
        };
      };
      uptime = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show uptime and load in the operations bar.";
        };
        interval = mkOption {
          type = types.int;
          default = 30;
          description = "Refresh interval in seconds.";
        };
      };
    };

    banners = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Global switch for all Waybar API/data banners.";
      };

      dismissable = mkOption {
        type = types.bool;
        default = true;
        description = "Allow runtime hiding/showing of Waybar banners via clicks.";
      };

      crypto = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show BTC/ETH ticker in the waybar.";
        };
        symbols = mkOption {
          type = types.listOf types.str;
          default = [
            "bitcoin"
            "ethereum"
          ];
          description = "CoinGecko ids to fetch (comma joined in the API call).";
        };
        interval = mkOption {
          type = types.int;
          default = 120;
          description = "Refresh interval in seconds.";
        };
      };

      hackerNews = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Show scrolling Hacker News top headline.";
        };
        feed = mkOption {
          type = types.enum [
            "topstories"
            "beststories"
            "newstories"
          ];
          default = "topstories";
          description = "Hacker News Firebase feed to show.";
        };
        maxTitleLength = mkOption {
          type = types.int;
          default = 48;
          description = "Maximum visible headline length.";
        };
        interval = mkOption {
          type = types.int;
          default = 300;
          description = "Refresh interval in seconds.";
        };
      };

      weather = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show current weather via wttr.in.";
        };
        location = mkOption {
          type = types.str;
          default = "";
          description = "wttr.in location code (empty = auto-detect by IP).";
        };
        interval = mkOption {
          type = types.int;
          default = 900;
          description = "Refresh interval in seconds.";
        };
      };

      stocks = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Show stock ticker via public Stooq CSV quote endpoint.";
        };
        symbols = mkOption {
          type = types.listOf types.str;
          default = [
            "AAPL"
            "NVDA"
            "TSLA"
          ];
          description = "Ticker symbols to poll.";
        };
        interval = mkOption {
          type = types.int;
          default = 180;
          description = "Refresh interval in seconds.";
        };
      };
    };

    wallpaper = {
      directory = mkOption {
        type = types.str;
        default = "Pictures/wallpapers";
        description = "Home-relative directory scanned by the wallpaper rotator.";
      };
      rotate = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the swww rotating wallpaper timer.";
      };
      interval = mkOption {
        type = types.str;
        default = "30min";
        description = "systemd OnUnitActiveSec value for the rotator.";
      };
      seed = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Install the generated Matrix simulation wallpaper into the wallpaper directory.";
        };
        fileName = mkOption {
          type = types.str;
          default = "nixos-hacker-box-matrix-simulation.png";
          description = "Installed file name for the generated wallpaper.";
        };
        source = mkOption {
          type = types.path;
          default = ../../assets/wallpapers/nixos-hacker-box-matrix-simulation.png;
          description = "Source image for the Matrix simulation wallpaper seed.";
        };
      };
      ascii = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Install and prefer the optional code-generated ASCII wallpaper.";
        };
        fileName = mkOption {
          type = types.str;
          default = "nixos-hacker-box-ascii.png";
          description = "Installed file name for the generated ASCII wallpaper.";
        };
        width = mkOption {
          type = types.int;
          default = 2560;
          description = "Generated wallpaper width in pixels.";
        };
        height = mkOption {
          type = types.int;
          default = 1440;
          description = "Generated wallpaper height in pixels.";
        };
      };
      transition = {
        type = mkOption {
          type = types.str;
          default = "grow";
          description = "swww transition type used by the rotator.";
        };
        duration = mkOption {
          type = types.float;
          default = 2.0;
          description = "swww transition duration in seconds.";
        };
        fps = mkOption {
          type = types.int;
          default = 60;
          description = "swww transition FPS.";
        };
        step = mkOption {
          type = types.int;
          default = 90;
          description = "swww transition step.";
        };
      };
    };
  };
}
