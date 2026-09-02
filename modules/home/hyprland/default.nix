/*
  home/hyprland/default.nix — Hyprland compositor module tree root.

  Native + parametric layering
  ----------------------------
  1. `hyprland/hyprland.conf` — the static bits (monitors, exec-once,
     input, keybindings, dwindle, misc). Edited natively and left untouched;
     a narrowly scoped compatibility filter removes only directives retired
     by Hyprland 0.55 before the generated configuration is assembled.
  2. Nix `extraConfig` — the parametric visuals (borders, decoration,
     blur, animations, window/layer rules) generated from `myTheme.*`.
     Because Hyprland reads keys in file order and last write wins,
     placing this AFTER the native config means it authoritatively sets
     the look-and-feel — the native file just needs to *exist* to define
     the base.

  Plugin: hyprexpo
  ----------------
  `.so` lives in the Nix store (unpredictable path) — we prepend a
  `$HYPREXPO_PATH` variable so `hyprland.conf` can reference the plugin
  symbolically.

  settings = {}
  -------------
  Empty on purpose — otherwise Home Manager would generate a second
  hyprland.conf and the two would fight for precedence.
*/
{
  pkgs,
  config,
  inputs,
  lib,
  unstable,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  hyprlandPackage = inputs.hyprland.packages.${system}.hyprland;
  hyprexpo = inputs.hyprexpo.packages.${system}.default.overrideAttrs (_: {
    version = "0.55.4";
    src = inputs.hyprexpo-source;
  });
  t = config.myTheme;

  # Hyprland rgba: 8-char hex "RRGGBBAA". Nix opacity 0.0-1.0 → 0-255 hex.
  toHex2 =
    f:
    let
      n = builtins.floor (f * 255.0 + 0.5);
      s = lib.toHexString (
        if n < 0 then
          0
        else if n > 255 then
          255
        else
          n
      );
    in
    if builtins.stringLength s == 1 then "0${s}" else s;

  stripHash = h: lib.removePrefix "#" h;
  hyprRgba = hex: alpha: "rgba(${stripHash hex}${toHex2 alpha})";

  # Preserve the unmanaged source file while keeping its generated 0.55 view
  # free of removed dispatchers and routing terminal/launcher bindings through
  # their managed single-instance session wrappers.
  nativeConfig =
    builtins.replaceStrings
      [
        "exec-once = hyprctl plugin load $HYPREXPO_PATH\n"
        "bind = $mainMod, T, togglesplit,\n"
        "bind = $mainMod CTRL, J, togglesplit,\n"
        "bind = $mainMod, Tab, hyprexpo:expo, toggle\n"
        "bind = $mainMod, mouse:274, hyprexpo:expo, toggle\n"
        "bind = $mainMod, Q, exec, kitty\n"
        "bind = $mainMod, Return, exec, kitty\n"
        "bind = $mainMod, R, exec, wofi --show drun\n"
        "bind = $mainMod, D, exec, wofi --show drun\n"
      ]
      [
        "# HyprExpo loading is managed by the Nix compatibility layer.\n"
        "# Hyprland 0.55 replacement is appended by the session UI layer.\n"
        "# Hyprland 0.55 replacement is appended by the session UI layer.\n"
        "# HyprExpo binding is installed through an exec dispatcher below.\n"
        "# HyprExpo mouse binding is installed through an exec dispatcher below.\n"
        "bind = $mainMod, Q, exec, hb-terminal\n"
        "bind = $mainMod, Return, exec, hb-terminal\n"
        "bind = $mainMod, R, exec, hb-wofi drun\n"
        "bind = $mainMod, D, exec, hb-wofi drun\n"
      ]
      (builtins.readFile ./hyprland.conf);

  loadHyprexpoScript = pkgs.writeShellApplication {
    name = "hb-load-hyprexpo";
    runtimeInputs = [
      hyprlandPackage
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      plugin=${hyprexpo}/lib/libhyprexpo.so

      for _ in $(seq 1 25); do
        if hyprctl plugin list 2>/dev/null | grep -Fq hyprexpo; then
          exit 0
        fi
        if hyprctl plugin load "$plugin" >/dev/null 2>&1; then
          exit 0
        fi
        sleep 0.2
      done

      hyprctl notify 3 3000 "${hyprRgba t.danger 1.0}" "HyprExpo failed to load" >/dev/null 2>&1 || true
    '';
  };

  hyprexpoToggleScript = pkgs.writeShellApplication {
    name = "hb-hyprexpo-toggle";
    runtimeInputs = [ hyprlandPackage ];
    text = ''
      hyprctl dispatch hyprexpo:expo toggle >/dev/null 2>&1 || true
    '';
  };

  switchLayoutScript = pkgs.writeShellApplication {
    name = "hb-switch-layout";
    runtimeInputs = with pkgs; [
      hyprlandPackage
      jq
      coreutils
    ];
    text = ''
      if ! hyprctl switchxkblayout all next >/dev/null 2>&1; then
        hyprctl notify 0 1800 "${hyprRgba t.danger 1.0}" "keyboard layout switch failed" >/dev/null 2>&1 || true
        exit 0
      fi

      devices=$(hyprctl devices -j 2>/dev/null || true)
      layout=$(printf '%s' "$devices" \
        | jq -r '[.keyboards[]? | select(.main == true).active_keymap][0] // [.keyboards[]?.active_keymap][0] // "layout"' 2>/dev/null \
        | cut -c1-12 || true)
      [ -n "$layout" ] || layout="layout"

      hyprctl notify 2 1200 "${hyprRgba t.accent 1.0}" "KB $layout" >/dev/null 2>&1 || true
    '';
  };

  # Single-instance kitty launcher. Every SUPER+Q / SUPER+Return re-enters
  # the same kitty process (--single-instance + --instance-group), so a
  # second press adds a window to the existing cockpit instead of forking
  # a whole new emulator, and the tmux `hb` session is always the shell.
  terminalScript = pkgs.writeShellApplication {
    name = "hb-terminal";
    runtimeInputs = with pkgs; [
      kitty
      tmux
      coreutils
    ];
    text = ''
      cockpit_init="${cockpitInitScript}/bin/hb-cockpit-init"

      exec kitty \
        --single-instance \
        --instance-group hb-terminal \
        --listen-on unix:@hb-terminal \
        --class hb-terminal \
        --title 'HB · cockpit' \
        -- "$cockpit_init"
    '';
  };

  # Interactive bootstrap for the cockpit shell: fixed workspaces plus three
  # appliance panes (Pi, docs, control). Later kitty windows join the same
  # session. `ensure_appliance` also upgrades existing hb sessions without
  # destroying the user's shell, nixos, ops or ad-hoc development windows.
  cockpitInitScript = pkgs.writeShellApplication {
    name = "hb-cockpit-init";
    runtimeInputs = with pkgs; [
      tmux
      zsh
      coreutils
      gnugrep
    ];
    text = ''
      if [ -n "''${TMUX:-}" ]; then
        exec zsh -l
      fi

      mode=$(cat /var/lib/hb-mode/current 2>/dev/null || echo dev)
      tmux set-environment -g HB_MODE "$mode" >/dev/null 2>&1 || true

      if ! tmux has-session -t hb 2>/dev/null; then
        tmux new-session  -d -s hb -n shell -c "$HOME"
        tmux new-window   -t hb:  -n nixos -c /etc/nixos
        tmux new-window   -t hb:  -n ops   -c "$HOME"
        tmux set-environment -t hb HB_MODE "$mode" >/dev/null 2>&1 || true
      fi

      ensure_appliance() {
        window=$1
        directory=$2
        command=$3
        marker=$4

        if ! tmux list-windows -t hb -F '#{window_name}' | grep -Fxq "$window"; then
          tmux new-window -d -t hb: -n "$window" -c "$directory" "$command"
        elif [ "$(tmux show-options -w -v -t "hb:$window" "$marker" 2>/dev/null || true)" != 1 ]; then
          tmux respawn-pane -k -t "hb:$window" -c "$directory" "$command"
        fi

        tmux set-option -w -t "hb:$window" "$marker" 1
        tmux set-option -w -t "hb:$window" @hb-appliance 1
      }

      ensure_appliance pi /etc/nixos 'exec hb-pi-workspace' @hb-pi-pane
      ensure_appliance docs /etc/nixos 'exec hb-docs pane' @hb-docs-pane
      ensure_appliance control "$HOME" 'exec hb-control-center pane' @hb-control-pane
      tmux select-window -t hb:shell

      exec tmux attach-session -t hb
    '';
  };

  # Single-instance wofi. Subsequent SUPER+R / SUPER+D presses toggle the
  # already visible launcher instead of stacking a second copy over it.
  # A tiny flock guards against the race where two rapid presses race
  # through the pgrep check before the first kill takes effect.
  wofiScript = pkgs.writeShellApplication {
    name = "hb-wofi";
    runtimeInputs = with pkgs; [
      unstable.wofi
      procps
      coreutils
      util-linux
    ];
    text = ''
      mode="''${1:-drun}"
      case "$mode" in
        drun|run|dmenu|window|filebrowser) ;;
        *)
          printf 'hb-wofi: unknown mode: %s\n' "$mode" >&2
          exit 2
          ;;
      esac

      lock_dir="''${XDG_RUNTIME_DIR:-/tmp}"
      exec 9>"$lock_dir/hb-wofi.lock"
      flock -n 9 || exit 0

      if pgrep -x wofi >/dev/null 2>&1; then
        pkill -x wofi
        exit 0
      fi

      exec wofi --show "$mode"
    '';
  };

  uiModeScript = pkgs.writeShellApplication {
    name = "hb-ui-apply";
    runtimeInputs = [
      hyprlandPackage
      unstable.swaynotificationcenter
      unstable.awww
      pkgs.coreutils
      pkgs.findutils
      pkgs.kitty
      pkgs.tmux
      pkgs.wireplumber
    ];
    text = ''
      mode="''${1:---current}"
      if [ "$mode" = "--current" ]; then
        mode=$(cat /var/lib/hb-mode/current 2>/dev/null || echo dev)
      fi

      case "$mode" in
        study)
          bar_layout=intel; dnd=on; window_layout=master; volume=45
          gaps_in=8; gaps_out=18; rounding=10
          active_opacity=0.96; inactive_opacity=0.84; dim_strength=0.18
          animations=true; blur=true
          accent=66d9ff; secondary=bd93f9; background=07111c; foreground=d7e2ff
          ;;
        dev)
          bar_layout=main; dnd=off; window_layout=dwindle; volume=keep
          gaps_in=4; gaps_out=12; rounding=${toString t.border.rounding}
          active_opacity=${toString t.opacity.active}; inactive_opacity=${toString t.opacity.inactive}; dim_strength=0.12
          animations=true; blur=true
          accent=${lib.removePrefix "#" t.accent}; secondary=${lib.removePrefix "#" t.accentSecondary}; background=${lib.removePrefix "#" t.base}; foreground=${lib.removePrefix "#" t.fg}
          ;;
        hack|recon)
          bar_layout=ops; dnd=on; window_layout=dwindle; volume=keep
          gaps_in=2; gaps_out=6; rounding=2
          active_opacity=0.96; inactive_opacity=0.80; dim_strength=0.08
          animations=true; blur=false
          accent=00ff88; secondary=ff3355; background=050b08; foreground=d7ffe8
          ;;
        work)
          bar_layout=main; dnd=off; window_layout=master; volume=keep
          gaps_in=6; gaps_out=10; rounding=6
          active_opacity=0.98; inactive_opacity=0.88; dim_strength=0.16
          animations=true; blur=true
          accent=5ea1ff; secondary=00ffff; background=080d18; foreground=e6edff
          ;;
        personal)
          bar_layout=launch; dnd=off; window_layout=dwindle; volume=keep
          gaps_in=6; gaps_out=14; rounding=10
          active_opacity=0.94; inactive_opacity=0.82; dim_strength=0.12
          animations=true; blur=true
          accent=ff00ff; secondary=00ffff; background=120718; foreground=f3dcff
          ;;
        focus)
          bar_layout=main; dnd=on; window_layout=master; volume=35
          gaps_in=10; gaps_out=24; rounding=8
          active_opacity=1.0; inactive_opacity=0.70; dim_strength=0.30
          animations=false; blur=true
          accent=8be9fd; secondary=50fa7b; background=05070a; foreground=f2f8ff
          ;;
        night)
          bar_layout=infra; dnd=on; window_layout=dwindle; volume=25
          gaps_in=4; gaps_out=10; rounding=8
          active_opacity=0.92; inactive_opacity=0.74; dim_strength=0.24
          animations=true; blur=false
          accent=ffb000; secondary=ff6b6b; background=0d0907; foreground=ffe8bf
          ;;
        server)
          bar_layout=infra; dnd=on; window_layout=master; volume=keep
          gaps_in=2; gaps_out=4; rounding=2
          active_opacity=1.0; inactive_opacity=0.86; dim_strength=0.08
          animations=false; blur=false
          accent=768096; secondary=00ff88; background=07090f; foreground=d7e2ff
          ;;
        *)
          printf 'hb-ui-apply: unknown mode: %s\n' "$mode" >&2
          exit 2
          ;;
      esac

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hacker-box"
      palette_file="$state_dir/kitty-mode.conf"
      mkdir -p "$state_dir"

      {
        printf 'background #%s\n' "$background"
        printf 'foreground #%s\n' "$foreground"
        printf 'cursor #%s\n' "$accent"
        printf 'cursor_text_color #%s\n' "$background"
        printf 'selection_background #%s\n' "$accent"
        printf 'selection_foreground #%s\n' "$background"
        printf 'active_border_color #%s\n' "$accent"
        printf 'inactive_border_color #%s\n' "$secondary"
        printf 'active_tab_background #%s\n' "$accent"
        printf 'active_tab_foreground #%s\n' "$background"
        printf 'inactive_tab_background #%s\n' "$background"
        printf 'inactive_tab_foreground #%s\n' "$foreground"
      } > "$palette_file.tmp"
      mv "$palette_file.tmp" "$palette_file"
      printf '%s\n' "$mode" > "$state_dir/ui-mode"

      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl keyword general:gaps_in "$gaps_in" >/dev/null 2>&1 || true
        hyprctl keyword general:gaps_out "$gaps_out" >/dev/null 2>&1 || true
        hyprctl keyword general:layout "$window_layout" >/dev/null 2>&1 || true
        hyprctl keyword general:col.active_border "rgba($accent) rgba($secondary) 45deg" >/dev/null 2>&1 || true
        hyprctl keyword decoration:rounding "$rounding" >/dev/null 2>&1 || true
        hyprctl keyword decoration:active_opacity "$active_opacity" >/dev/null 2>&1 || true
        hyprctl keyword decoration:inactive_opacity "$inactive_opacity" >/dev/null 2>&1 || true
        hyprctl keyword decoration:dim_strength "$dim_strength" >/dev/null 2>&1 || true
        hyprctl keyword decoration:blur:enabled "$blur" >/dev/null 2>&1 || true
        hyprctl keyword decoration:shadow:color "rgba($accent)59" >/dev/null 2>&1 || true
        hyprctl keyword animations:enabled "$animations" >/dev/null 2>&1 || true
        hyprctl keyword group:col.border_active "rgba($accent)" >/dev/null 2>&1 || true
      fi

      if command -v waybar-layout >/dev/null 2>&1; then
        waybar-layout "$bar_layout" >/dev/null 2>&1 || true
      fi

      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        if [ "$dnd" = on ]; then
          swaync-client --skip-wait --dnd-on >/dev/null 2>&1 || true
        else
          swaync-client --skip-wait --dnd-off >/dev/null 2>&1 || true
        fi
      fi

      if tmux list-sessions >/dev/null 2>&1; then
        tmux set-environment -g HB_MODE "$mode" >/dev/null 2>&1 || true
        tmux refresh-client -S >/dev/null 2>&1 || true
      fi

      kitty @ --to unix:@hb-terminal set-colors --all --configured "$palette_file" >/dev/null 2>&1 || true

      # Mode-specific wallpaper: any image under ~/Pictures/wallpapers/modes/<mode>/
      # is preferred over the base rotator when present. Silent no-op otherwise.
      mode_wall_dir="$HOME/Pictures/wallpapers/modes/$mode"
      if [ -d "$mode_wall_dir" ]; then
        mode_wall=$(find "$mode_wall_dir" -type f \
          \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
          | head -n1)
        if [ -n "$mode_wall" ] && command -v awww >/dev/null 2>&1; then
          awww img "$mode_wall" --transition-type fade --transition-duration 1.5 >/dev/null 2>&1 || true
        fi
      fi

      # Dampen master output for quiet personas; leave the sink alone for
      # work/hack/dev/personal/server where the user may already have set
      # a preferred level.
      if [ "$volume" != keep ] && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "0.''${volume}" >/dev/null 2>&1 || true
      fi

      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl notify -1 2500 "rgba(''${accent}ff)" "MODE · $mode" >/dev/null 2>&1 || true
      fi

      printf 'ui mode: %s · bar: %s · layout: %s · dnd: %s · vol: %s\n' \
        "$mode" "$bar_layout" "$window_layout" "$dnd" "$volume"
    '';
  };

  clipboardMenuScript = pkgs.writeShellApplication {
    name = "hb-clip-menu";
    runtimeInputs = with pkgs; [
      cliphist
      wofi
      wl-clipboard
      coreutils
    ];
    text = ''
      selection=$(cliphist list | wofi --dmenu --prompt clipboard || true)
      [ -n "$selection" ] || exit 0
      printf '%s' "$selection" | cliphist decode | wl-copy
    '';
  };

  deckLauncher =
    {
      name,
      workspace,
      class,
      title,
      command,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        hyprlandPackage
        kitty
        jq
        bash
        coreutils
        gnugrep
        gnused
        gawk
        iproute2
        procps
        systemd
        btop
        git
        ripgrep
        findutils
        docker_29
        podman
        libvirt
      ];
      text = ''
        workspace="${workspace}"
        class="${class}"

        ensure_workspace() {
          current=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // ""' 2>/dev/null || true)
          if [ "$current" != "special:$workspace" ]; then
            hyprctl dispatch togglespecialworkspace "$workspace" >/dev/null 2>&1 || true
          fi
        }

        if hyprctl clients -j 2>/dev/null | jq -e --arg class "$class" 'any(.[]; .class == $class)' >/dev/null; then
          ensure_workspace
          exit 0
        fi

        ensure_workspace
        kitty --class "$class" --title "${title}" bash -lc ${lib.escapeShellArg command} >/dev/null 2>&1 &
      '';
    };

  opsDeckScript = deckLauncher {
    name = "hb-ops-deck";
    workspace = "ops";
    class = "hb-ops-deck";
    title = "OPS DECK";
    command = ''
      exec btop
    '';
  };

  netDeckScript = deckLauncher {
    name = "hb-net-deck";
    workspace = "net";
    class = "hb-net-deck";
    title = "NET DECK";
    command = ''
      while true; do
        clear
        date '+NET %F %T'
        printf '\ninterfaces\n'
        ip -brief addr show
        printf '\nroutes\n'
        ip route show
        printf '\nlistening sockets\n'
        ss -ltnup 2>/dev/null | sed -n '1,80p'
        sleep 2
      done
    '';
  };

  secDeckScript = deckLauncher {
    name = "hb-sec-deck";
    workspace = "sec";
    class = "hb-sec-deck";
    title = "SECURITY DECK";
    command = ''
      while true; do
        clear
        date '+SEC %F %T'
        printf '\ncritical units\n'
        systemctl --no-pager --plain is-active sshd.service fail2ban.service tailscaled.service tor.service 2>/dev/null || true
        printf '\nssh auth events, last 2h\n'
        journalctl -u sshd --since '2 hours ago' --no-pager 2>/dev/null | tail -45 || true
        sleep 5
      done
    '';
  };

  scratchDeckScript = deckLauncher {
    name = "hb-scratch-deck";
    workspace = "scratch";
    class = "hb-scratch-deck";
    title = "SCRATCH";
    command = ''
      exec bash -l
    '';
  };

  infraDeckScript = deckLauncher {
    name = "hb-infra-deck";
    workspace = "infra";
    class = "hb-infra-deck";
    title = "INFRA DECK";
    command = ''
      cd /etc/nixos || exit 0
      while true; do
        clear
        date '+INFRA %F %T'
        printf '\nflake repo\n'
        git status --short --branch 2>/dev/null || true
        printf '\nlast commits\n'
        git --no-pager log --oneline -8 2>/dev/null || true
        printf '\ncurrent / booted system\n'
        printf 'current: '
        readlink /run/current-system 2>/dev/null || true
        printf 'booted : '
        readlink /run/booted-system 2>/dev/null || true
        printf '\nops timers\n'
        systemctl --no-pager --plain list-timers 'restic-*' 'nextcloud-*' 'agent-*' 'obs-*' 2>/dev/null | sed -n '1,28p' || true
        sleep 5
      done
    '';
  };

  auditDeckScript = deckLauncher {
    name = "hb-audit-deck";
    workspace = "audit";
    class = "hb-audit-deck";
    title = "AUDIT DECK";
    command = ''
      while true; do
        clear
        date '+AUDIT %F %T'
        printf '\nfailed units\n'
        systemctl --failed --no-pager --plain 2>/dev/null || true
        printf '\ncore services\n'
        systemctl --no-pager --plain is-active \
          sshd.service fail2ban.service tailscaled.service \
          caddy.service nginx.service postgresql.service \
          prometheus.service grafana.service loki.service \
          ollama.service open-webui.service 2>/dev/null || true
        printf '\nboot warnings\n'
        journalctl -p warning..alert -b --no-pager 2>/dev/null | tail -80 || true
        sleep 5
      done
    '';
  };

  labDeckScript = deckLauncher {
    name = "hb-lab-deck";
    workspace = "lab";
    class = "hb-lab-deck";
    title = "LAB DECK";
    command = ''
      while true; do
        clear
        date '+LAB %F %T'
        printf '\npodman containers\n'
        podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
        printf '\ndocker containers\n'
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
        printf '\nlibvirt domains\n'
        virsh -c qemu:///system list --all 2>/dev/null || true
        printf '\nprocess pressure\n'
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu | sed -n '1,18p'
        sleep 3
      done
    '';
  };

  agentDeckScript = deckLauncher {
    name = "hb-agent-deck";
    workspace = "agents";
    class = "hb-agent-deck";
    title = "AGENT CONFIG LENS";
    command = ''
      while true; do
        clear
        date '+AGENT LENS %F %T'
        printf '\nmode\n'
        /run/current-system/sw/bin/hb-mode status 2>/dev/null || echo unknown

        printf '\nmode table\n'
        /run/current-system/sw/bin/hb-mode list 2>/dev/null | sed -n '1,14p' || true

        printf '\nconfiguration imports\n'
        rg -n '^\s*\./modules/(agents|ai|hub|monitoring|cloud|nas|security|system/modes)' /etc/nixos/configuration.nix 2>/dev/null \
          | sed -n '1,28p' || true

        printf '\nagent module inventory\n'
        find /etc/nixos/modules/agents -maxdepth 2 -type f -name '*.nix' -printf '%P\n' 2>/dev/null \
          | sort | sed -n '1,60p' || true

        printf '\nagent / observatory timers\n'
        systemctl list-timers --all --no-pager --plain 'agent-*' 'obs-*' 2>/dev/null | sed -n '1,38p' || true

        printf '\nfailed agent / observatory units\n'
        systemctl --failed --no-pager --plain 'agent-*' 'obs-*' 2>/dev/null || true

        if [ -r /var/lib/observatory/events.jsonl ]; then
          printf '\nlast observatory events\n'
          tail -20 /var/lib/observatory/events.jsonl 2>/dev/null \
            | jq -r '[.ts // .time // "", .source // .producer // "", .type // .event // ""] | @tsv' 2>/dev/null \
            | sed -n '1,20p' || true
        fi

        printf '\nrepo state\n'
        git -C /etc/nixos status --short --branch 2>/dev/null | sed -n '1,28p' || true
        sleep 5
      done
    '';
  };

  piSessionCommand = lib.escapeShellArg ''
    cd /etc/nixos || exit 1
    pi_bin="${config.home.homeDirectory}/.local/pi/node_modules/.bin/pi"

    if [ ! -x "$pi_bin" ]; then
      printf '%s\n' \
        "Pi is not installed yet." \
        "Run home-manager switch or make switch, then reopen this panel."
      exec ${pkgs.bash}/bin/bash -l
    fi

    exec ${pkgs.tmux}/bin/tmux new-session -A -s pi "$pi_bin --agent hacker-box --name hacker-box"
  '';

  piDeckScript = pkgs.writeShellApplication {
    name = "hb-pi";
    excludeShellChecks = [ "SC2016" ];
    runtimeInputs = with pkgs; [
      hyprlandPackage
      kitty
      jq
      bash
      coreutils
    ];
    text = ''
      workspace="pi"
      class="hb-pi-deck"

      if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        exec bash -lc ${piSessionCommand}
      fi

      ensure_workspace() {
        current=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // ""' 2>/dev/null || true)
        if [ "$current" != "special:$workspace" ]; then
          hyprctl dispatch togglespecialworkspace "$workspace" >/dev/null 2>&1 || true
        fi
      }

      if hyprctl clients -j 2>/dev/null | jq -e --arg class "$class" 'any(.[]; .class == $class)' >/dev/null; then
        ensure_workspace
        exit 0
      fi

      ensure_workspace
      kitty --class "$class" --title "PI DECK" bash -lc ${piSessionCommand} >/dev/null 2>&1 &
    '';
  };

  # Graphical mode picker — presents `hb-mode list` through wofi and
  # dispatches the choice. Used from SUPER+SHIFT+M, the Waybar mode
  # widget (right-click) and the hb-command-center menu.
  modePickScript = pkgs.writeShellApplication {
    name = "hb-mode-pick";
    runtimeInputs = with pkgs; [
      unstable.wofi
      coreutils
      gnused
    ];
    text = ''
      choice=$(/run/current-system/sw/bin/hb-mode list 2>/dev/null \
        | sed 's/^  //' \
        | wofi --dmenu --prompt 'hb-mode' --width 520 --height 360 || true)
      [ -n "$choice" ] || exit 0
      mode=$(printf '%s' "$choice" | awk '{print $1}')
      [ -n "$mode" ] || exit 0
      /run/current-system/sw/bin/hb-mode "$mode"
    '';
  };

  modeCycleScript = pkgs.writeShellApplication {
    name = "hb-mode-cycle";
    runtimeInputs = with pkgs; [
      coreutils
      procps
    ];
    text = ''
      order="${lib.concatStringsSep " " t.modes.cycle}"
      current=$(/run/current-system/sw/bin/hb-mode status 2>/dev/null || echo dev)
      next=""
      first=""

      for mode in $order; do
        [ -n "$first" ] || first="$mode"
        if [ -n "$next" ]; then
          next="$mode"
          break
        fi
        if [ "$mode" = "$current" ]; then
          next="pending"
        fi
      done

      [ -n "$next" ] && [ "$next" != "pending" ] || next="$first"
      /run/current-system/sw/bin/hb-mode "$next" || true

      for signal in 13 14 15 16 17 18 19; do
        pkill "-RTMIN+$signal" waybar >/dev/null 2>&1 || true
      done
    '';
  };

  commandCenterScript = pkgs.writeShellApplication {
    name = "hb-command-center";
    runtimeInputs = with pkgs; [
      wofi
      hyprlandPackage
      piDeckScript
      modePickScript
      coreutils
      procps
      systemd
      libnotify
    ];
    text = ''
      choice=$(printf '%s\n' \
        'mode pick…' \
        'mode study' \
        'mode dev' \
        'mode hack' \
        'mode work' \
        'mode personal' \
        'mode focus' \
        'mode night' \
        'mode server' \
        'bar main' \
        'bar ops' \
        'bar infra' \
        'bar intel' \
        'bar launch' \
        'deck agents/config' \
        'deck pi' \
        'deck ops' \
        'deck net' \
        'deck security' \
        'deck infra' \
        'deck audit' \
        'deck lab' \
        'wallpaper rotate' \
        'waybar restart' \
        'hyprland reload' \
        'lock' \
        | wofi --dmenu --prompt 'hb command' || true)

      [ -n "$choice" ] || exit 0

      case "$choice" in
        'mode pick…') hb-mode-pick ;;
        'mode study') /run/current-system/sw/bin/hb-mode study ;;
        'mode dev') /run/current-system/sw/bin/hb-mode dev ;;
        'mode hack') /run/current-system/sw/bin/hb-mode hack ;;
        'mode work') /run/current-system/sw/bin/hb-mode work ;;
        'mode personal') /run/current-system/sw/bin/hb-mode personal ;;
        'mode focus') /run/current-system/sw/bin/hb-mode focus ;;
        'mode night') /run/current-system/sw/bin/hb-mode night ;;
        'mode server') /run/current-system/sw/bin/hb-mode server ;;
        'bar main') waybar-layout main ;;
        'bar ops') waybar-layout ops ;;
        'bar infra') waybar-layout infra ;;
        'bar intel') waybar-layout intel ;;
        'bar launch') waybar-layout launch ;;
        'deck agents/config') hb-agent-deck ;;
        'deck pi') hb-pi ;;
        'deck ops') hb-ops-deck ;;
        'deck net') hb-net-deck ;;
        'deck security') hb-sec-deck ;;
        'deck infra') hb-infra-deck ;;
        'deck audit') hb-audit-deck ;;
        'deck lab') hb-lab-deck ;;
        'wallpaper rotate') swww-rotate ;;
        'waybar restart') systemctl --user restart waybar.service || pkill waybar || true ;;
        'hyprland reload') hyprctl reload ;;
        'lock') hyprlock ;;
      esac

      for signal in 13 14 15 16 17 18 19; do
        pkill "-RTMIN+$signal" waybar >/dev/null 2>&1 || true
      done
    '';
  };

  cyberpunkOverrides = ''
    # ==========================================================================
    # PARAMETRIC OVERRIDES — generated from myTheme (modules/home/theme.nix)
    # ==========================================================================

    general {
        gaps_in = 4
        gaps_out = 12
        border_size = ${toString t.border.size}
        col.active_border = ${hyprRgba t.accent 1.0} ${hyprRgba t.accentSecondary 1.0} 45deg
        col.inactive_border = ${hyprRgba t.fgDim 0.6}
        layout = dwindle
        allow_tearing = false
        resize_on_border = true
        no_focus_fallback = true
    }

    decoration {
        rounding = ${toString t.border.rounding}
        rounding_power = 3.0
        active_opacity = ${toString t.opacity.active}
        inactive_opacity = ${toString t.opacity.inactive}
        fullscreen_opacity = 1.0
        dim_inactive = true
        dim_strength = 0.12
        dim_special = 0.30
        shadow {
            enabled = true
            range = 24
            render_power = 3
            color = ${hyprRgba t.accent 0.35}
            color_inactive = ${hyprRgba t.base 0.6}
            scale = 0.98
        }
        blur {
            enabled = true
            size = ${toString t.blur.size}
            passes = ${toString t.blur.passes}
            new_optimizations = true
            xray = true
            ignore_opacity = true
            noise = 0.02
            contrast = 1.10
            brightness = 0.95
            vibrancy = 0.20
            vibrancy_darkness = 0.12
            popups = true
            popups_ignorealpha = 0.18
        }
    }

    # Hyprland 0.55 anonymous rules: match first, explicit effect values.
    layerrule = match:namespace waybar, blur on, ignore_alpha 0
    layerrule = match:namespace wofi, blur on, ignore_alpha 0
    layerrule = match:namespace notifications, blur on, ignore_alpha 0
    layerrule = match:namespace swaync-control-center, blur on, ignore_alpha 0
    layerrule = match:namespace swaync-notification-window, blur on, ignore_alpha 0

    animations {
        enabled = yes
        bezier = cyber, 0.16, 1.00, 0.30, 1.00
        bezier = snap,  0.20, 0.90, 0.10, 1.02
        bezier = fade,  0.25, 0.10, 0.25, 1.00
        animation = windows,       1, 5, cyber, slide
        animation = windowsOut,    1, 4, cyber, popin 90%
        animation = windowsMove,   1, 4, snap
        animation = border,        1, 10, fade
        animation = borderangle,   1, 60, fade, loop
        animation = fade,          1, 6,  fade
        animation = fadeDim,       1, 5,  fade
        animation = workspaces,    1, 4,  cyber, slidevert
        animation = specialWorkspace, 1, 6, cyber, slidevert
    }

    # Cursor accent
    cursor {
        inactive_timeout = 8
        no_hardware_cursors = 2
        enable_hyprcursor = true
        sync_gsettings_theme = true
        hide_on_key_press = true
    }

    # Maintained HyprExpo: dynamic labelled workspace grid over the wallpaper.
    plugin {
        hyprexpo {
            columns = 3
            gaps_in = 8
            gaps_out = 14
            dynamic_grid = 1
            fill_gaps = 0
            mru_sort = 0
            show_workspace_names = 1
            label_pos = top_right
            label_size = 30
            wallpaper_bg = 1
            keynav_enable = 1
            keynav_wrap_h = 1
            keynav_wrap_v = 1
            show_cursor = 1
            show_pinned_windows = 0
            drag_drop_enable = 1
        }
    }

    # Native tabbed groups, styled with the same Matrix palette.
    group {
        insert_after_current = true
        focus_removed_window = true
        col.border_active = ${hyprRgba t.accent 1.0}
        col.border_inactive = ${hyprRgba t.fgDim 0.55}
        groupbar {
            enabled = true
            font_family = JetBrainsMono Nerd Font
            font_size = 11
            height = 24
            indicator_height = 2
            gradients = true
            col.active = ${hyprRgba t.accent 0.22}
            col.inactive = ${hyprRgba t.base 0.80}
            text_color = ${hyprRgba t.fg 1.0}
            text_color_inactive = ${hyprRgba t.fgDim 1.0}
        }
    }

    # Common window rules — native 0.55 syntax and cyberpunk polish.
    windowrule = match:class ^(pavucontrol)$, float on
    windowrule = match:class ^(nm-connection-editor)$, float on
    windowrule = match:class ^(org.kde.polkit-kde-authentication-agent-1)$, float on, opacity 1.0 override 1.0 override
    windowrule = match:title ^(Picture-in-Picture)$, float on, pin on, size 720 405, move 100%-740 100%-425

    # Operator decks on special workspaces
    windowrule = match:class ^(hb-ops-deck)$, workspace special:ops silent
    windowrule = match:class ^(hb-net-deck)$, workspace special:net silent
    windowrule = match:class ^(hb-sec-deck)$, workspace special:sec silent
    windowrule = match:class ^(hb-scratch-deck)$, workspace special:scratch silent
    windowrule = match:class ^(hb-infra-deck)$, workspace special:infra silent
    windowrule = match:class ^(hb-audit-deck)$, workspace special:audit silent
    windowrule = match:class ^(hb-lab-deck)$, workspace special:lab silent
    windowrule = match:class ^(hb-agent-deck)$, workspace special:agents silent
    windowrule = match:class ^(hb-pi-deck)$, workspace special:pi silent
    windowrule = match:class ^(hb-(ops|net|sec|scratch|infra|audit|lab|agent|pi)-deck)$, float on, center on, opacity 0.92 0.82
    windowrule = match:class ^(hb-(ops|net|sec|infra|audit|lab|agent)-deck)$, size 82% 78%
    windowrule = match:class ^(hb-scratch-deck)$, size 70% 62%
    windowrule = match:class ^(hb-pi-deck)$, size 88% 84%

    # Force opaque for media / picture-heavy apps
    windowrule = match:class ^(mpv)$, opacity 1.0 override 1.0 override
    windowrule = match:class ^(vlc)$, opacity 1.0 override 1.0 override
    windowrule = match:class ^(imv)$, opacity 1.0 override 1.0 override
    windowrule = match:title ^(.*(YouTube|Netflix|Twitch|Jellyfin).*)$, opacity 1.0 override 1.0 override
    windowrule = match:class ^(Gimp-.*)$, opacity 1.0 override 1.0 override
    windowrule = match:class ^(krita)$, opacity 1.0 override 1.0 override

    # Controlled transparency for daily tools
    windowrule = match:class ^(kitty)$, opacity ${toString t.opacity.terminal} 0.72
    windowrule = match:class ^(org.kde.dolphin)$, opacity 0.90 0.78
    windowrule = match:class ^(firefox)$, opacity ${toString t.opacity.active} ${toString t.opacity.inactive}
    windowrule = match:class ^(Code)$, opacity ${toString t.opacity.active} ${toString t.opacity.inactive}
    windowrule = match:class ^(VSCodium)$, opacity ${toString t.opacity.active} ${toString t.opacity.inactive}
    windowrule = match:class ^(dev.zed.Zed)$, opacity ${toString t.opacity.active} ${toString t.opacity.inactive}
  '';
in
{
  imports = [ ./ui ];

  home.packages = [
    switchLayoutScript
    clipboardMenuScript
    opsDeckScript
    netDeckScript
    secDeckScript
    scratchDeckScript
    infraDeckScript
    auditDeckScript
    labDeckScript
    agentDeckScript
    piDeckScript
    modeCycleScript
    commandCenterScript
    loadHyprexpoScript
    hyprexpoToggleScript
    uiModeScript
    terminalScript
    cockpitInitScript
    wofiScript
    modePickScript
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprlandPackage;
    settings = { };
    extraConfig = ''
      $HYPREXPO_PATH = ${hyprexpo}/lib/libhyprexpo.so
      exec-once = hb-load-hyprexpo

      ${nativeConfig}

      ${cyberpunkOverrides}

      bind = SUPER, Tab, exec, hb-hyprexpo-toggle
      bind = SUPER, mouse:274, exec, hb-hyprexpo-toggle
      bind = SUPER CTRL, P, exec, hb-pi
      bind = SUPER SHIFT, M, exec, hb-mode-pick
    '';
  };
}
