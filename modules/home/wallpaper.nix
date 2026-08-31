/*
  home/wallpaper.nix — Rotating wallpaper via swww.

  Installs a generated seed wallpaper, sets it at Hyprland startup, then
  rotates every `myTheme.wallpaper.interval` by picking a random image
  from `myTheme.wallpaper.directory`.

  Add images to that directory (jpg, png, webp).
*/
{
  pkgs,
  config,
  lib,
  unstable,
  ...
}:
let
  t = config.myTheme;
  cfg = config.myTheme.wallpaper;
  wallpaperDir = "$HOME/${cfg.directory}";
  initialWallpaperFile = if cfg.ascii.enable then cfg.ascii.fileName else cfg.seed.fileName;

  # SWWW was renamed to AWWW in 0.12. Keep tiny command shims for the
  # unmanaged native startup line while all managed code uses AWWW directly.
  swwwCompat = pkgs.writeShellApplication {
    name = "swww";
    runtimeInputs = [ unstable.awww ];
    text = ''
      exec awww "$@"
    '';
  };

  swwwDaemonCompat = pkgs.writeShellApplication {
    name = "swww-daemon";
    runtimeInputs = [ unstable.awww ];
    text = ''
      exec awww-daemon "$@"
    '';
  };

  asciiWallpaper =
    pkgs.runCommand "nixos-hacker-box-ascii-wallpaper.png"
      {
        nativeBuildInputs = [ pkgs.librsvg ];
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [
            pkgs.nerd-fonts.jetbrains-mono
            pkgs.dejavu_fonts
          ];
        };
      }
      ''
        cat > wallpaper.svg <<'SVG'
        <svg xmlns="http://www.w3.org/2000/svg" width="${toString cfg.ascii.width}" height="${toString cfg.ascii.height}" viewBox="0 0 ${toString cfg.ascii.width} ${toString cfg.ascii.height}">
          <defs>
            <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="${t.base}"/>
              <stop offset="55%" stop-color="#071522"/>
              <stop offset="100%" stop-color="#120718"/>
            </linearGradient>
            <radialGradient id="pulse" cx="74%" cy="28%" r="58%">
              <stop offset="0%" stop-color="${t.accent}" stop-opacity="0.20"/>
              <stop offset="44%" stop-color="${t.accentSecondary}" stop-opacity="0.10"/>
              <stop offset="100%" stop-color="${t.base}" stop-opacity="0"/>
            </radialGradient>
            <filter id="soft">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
            <style>
              .grid { stroke: ${t.accent}; stroke-width: 1; opacity: 0.09; }
              .scan { stroke: ${t.accentSecondary}; stroke-width: 2; opacity: 0.20; }
              .title { font-family: "JetBrainsMono Nerd Font", "DejaVu Sans Mono", monospace; font-size: 66px; font-weight: 800; fill: ${t.fg}; letter-spacing: 0; }
              .subtitle { font-family: "JetBrainsMono Nerd Font", "DejaVu Sans Mono", monospace; font-size: 24px; fill: ${t.accent}; letter-spacing: 0; }
              .ascii { font-family: "JetBrainsMono Nerd Font", "DejaVu Sans Mono", monospace; font-size: 30px; fill: ${t.good}; opacity: 0.82; }
              .term { font-family: "JetBrainsMono Nerd Font", "DejaVu Sans Mono", monospace; font-size: 25px; fill: ${t.fg}; opacity: 0.72; }
              .dim { fill: ${t.fgDim}; opacity: 0.58; }
              .magenta { fill: ${t.accentSecondary}; opacity: 0.76; }
              .amber { fill: ${t.warn}; opacity: 0.82; }
            </style>
          </defs>

          <rect width="100%" height="100%" fill="url(#bg)"/>
          <rect width="100%" height="100%" fill="url(#pulse)"/>
          <g>
            <path class="grid" d="M0 120H2560 M0 240H2560 M0 360H2560 M0 480H2560 M0 600H2560 M0 720H2560 M0 840H2560 M0 960H2560 M0 1080H2560 M0 1200H2560 M0 1320H2560"/>
            <path class="grid" d="M160 0V1440 M320 0V1440 M480 0V1440 M640 0V1440 M800 0V1440 M960 0V1440 M1120 0V1440 M1280 0V1440 M1440 0V1440 M1600 0V1440 M1760 0V1440 M1920 0V1440 M2080 0V1440 M2240 0V1440 M2400 0V1440"/>
            <path class="scan" d="M0 882H2560" filter="url(#soft)"/>
          </g>

          <text class="title" x="120" y="184">NIXOS HACKER BOX</text>
          <text class="subtitle" x="126" y="236">HYPRLAND // LOCAL OPS // MESH READY // LOW SIGNAL HIGH CONTROL</text>

          <text class="ascii" x="122" y="344">
            <tspan x="122" dy="0">      _   _ _____  _____   ____   _____  </tspan>
            <tspan x="122" dy="42">     | \ | |_   _|/ ____| / __ \ / ____| </tspan>
            <tspan x="122" dy="42">     |  \| | | | | |  __ | |  | | (___   </tspan>
            <tspan x="122" dy="42">     | . ` | | | | | |_ || |  | |\___ \  </tspan>
            <tspan x="122" dy="42">     | |\  |_| |_| |__| || |__| |____) | </tspan>
            <tspan x="122" dy="42">     |_| \_|_____|\_____| \____/|_____/  </tspan>
          </text>

          <text class="term" x="124" y="668">
            <tspan x="124" dy="0">[main@nixos-hacker-box]$ systemctl status sshd fail2ban tailscaled tor</tspan>
            <tspan x="124" dy="38" class="dim">sshd: hardened key+totp   fail2ban: armed   tailscale: mesh   tor: onion services</tspan>
            <tspan x="124" dy="64" class="amber">/var/log/auth :: watch the edge, reduce the noise, keep the workstation fast</tspan>
          </text>

          <text class="term magenta" x="1510" y="342">
            <tspan x="1510" dy="0">01001000 01011001 01010000 01010010</tspan>
            <tspan x="1510" dy="32">6e 69 78 6f 73 2d 68 61 63 6b 65 72</tspan>
            <tspan x="1510" dy="32">mesh:100.x     vault:onion     git:local</tspan>
            <tspan x="1510" dy="32">ports: observe before expose</tspan>
          </text>

          <text class="term dim" x="1514" y="706">
            <tspan x="1514" dy="0">+--------------------------------------------------+</tspan>
            <tspan x="1514" dy="34">|  super+o  ops deck      super+n  net deck        |</tspan>
            <tspan x="1514" dy="34">|  super+x  security      super+space key layout   |</tspan>
            <tspan x="1514" dy="34">|  super+i  infra         super+a audit/logs       |</tspan>
            <tspan x="1514" dy="34">|  super+u  lab           click spine widgets      |</tspan>
            <tspan x="1514" dy="34">|  super+h/j/k/l focus    super+g screen grab      |</tspan>
            <tspan x="1514" dy="34">+--------------------------------------------------+</tspan>
          </text>

          <text class="term" x="124" y="1178" opacity="0.55">
            <tspan x="124" dy="0">NIX STORE IMMUTABLE PATHS // DECLARATIVE DESKTOP // REBUILD, VERIFY, SWITCH</tspan>
            <tspan x="124" dy="36">crypto/news/weather/markets are volatile by design; the bar degrades cleanly when the net is hostile</tspan>
          </text>
        </svg>
        SVG

        rsvg-convert -w ${toString cfg.ascii.width} -h ${toString cfg.ascii.height} wallpaper.svg -o "$out"
      '';

  wallpaperSeed = pkgs.writeShellApplication {
    name = "hb-wallpaper-seed";
    runtimeInputs = [
      unstable.awww
      pkgs.coreutils
    ];
    text = ''
      IMG="${wallpaperDir}/${initialWallpaperFile}"
      [ -f "$IMG" ] || exit 0

      for _ in $(seq 1 20); do
        if awww img "$IMG" \
          --transition-type "${cfg.transition.type}" \
          --transition-fps ${toString cfg.transition.fps} \
          --transition-duration ${toString cfg.transition.duration} \
          --transition-step ${toString cfg.transition.step}; then
          exit 0
        fi
        sleep 0.2
      done

      exit 0
    '';
  };

  swwwRotate = pkgs.writeShellApplication {
    name = "swww-rotate";
    runtimeInputs = [
      unstable.awww
      pkgs.findutils
      pkgs.coreutils
    ];
    text = ''
      DIR="${wallpaperDir}"
      [ -d "$DIR" ] || exit 0

      IMG=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | shuf -n 1)
      [ -n "$IMG" ] || exit 0

      awww img "$IMG" \
        --transition-type "${cfg.transition.type}" \
        --transition-pos "$(( RANDOM % 100 ))%,$(( RANDOM % 100 ))%" \
        --transition-fps ${toString cfg.transition.fps} \
        --transition-duration ${toString cfg.transition.duration} \
        --transition-step ${toString cfg.transition.step}
    '';
  };
in
lib.mkMerge [
  {
    home.packages = [
      unstable.awww
      swwwCompat
      swwwDaemonCompat
      wallpaperSeed
      swwwRotate
    ];
  }

  (lib.mkIf cfg.seed.enable {
    home.file."${cfg.directory}/${cfg.seed.fileName}".source = cfg.seed.source;
  })

  (lib.mkIf cfg.ascii.enable {
    home.file."${cfg.directory}/${cfg.ascii.fileName}".source = asciiWallpaper;
  })

  (lib.mkIf cfg.rotate {
    systemd.user.services.swww-rotate = {
      Unit.Description = "Rotate the desktop wallpaper";
      Service = {
        Type = "oneshot";
        ExecStart = "${swwwRotate}/bin/swww-rotate";
      };
    };

    systemd.user.timers.swww-rotate = {
      Unit.Description = "Rotate wallpaper every ${cfg.interval}";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Unit = "swww-rotate.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  })
]
