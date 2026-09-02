/*
  home/waybar.nix — Waybar status bar (cyberpunk hacker theme).

  One top bar, five runtime layouts
  ---------------------------------
  main    workspaces · focused window · live desktop state
  ops     security mesh · LAN · sessions · uptime · UTC
  infra   NixOS state · services · storage · virtualisation
  intel   optional weather, market and Hacker News feeds
  launch  operator controls · Pi · agents · configuration intelligence

  `waybar-layout <main|ops|infra|intel|launch>` switches the composition.
  Only one Waybar surface runs at a time and every layout stays on the top
  edge, so the former lower bar and lateral rails consume no screen space.

  Tickers  (toggle-able from `myTheme.banners.*.enable`)
  --------
  · crypto      — BTC/ETH via CoinGecko (no auth)
  · hackerNews  — HN headline via Firebase API, click to open in browser
  · weather     — wttr.in JSON (no auth)
  · stocks      — Stooq CSV quote endpoint (no auth, best-effort)

  Every ticker is a `custom/*` module fed by a small shell script that
  emits waybar JSON. Failures never break the bar — degraded ticks emit
  a placeholder with `class = "error"` styled dim. Right-click any feed
  to hide it until the session restarts; the `feeds` control toggles all.

  Palette pulled from `config.myTheme.*`. Sharp corners, thin neon accent
  border, mono glyphs.
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
  b = t.banners;
  w = t.widgets;
  bar = t.bars.command;
  piBinary = "${config.home.homeDirectory}/.local/pi/node_modules/.bin/pi";

  hexByte =
    color: offset:
    toString (lib.fromHexString (builtins.substring offset 2 (lib.removePrefix "#" color)));

  cssRgba =
    color: alpha: "rgba(${hexByte color 0}, ${hexByte color 2}, ${hexByte color 4}, ${toString alpha})";

  # Escape a hex color for CSS use.
  cssHex = lib.id;

  isBannerEnabled = banner: b.enable && banner.enable;
  isOpsWidgetEnabled = widget: widget.enable;
  isSpineWidgetEnabled = widget: widget.enable;
  isHudWidgetEnabled = widget: widget.enable;

  enabledBannerNames =
    (lib.optional (isBannerEnabled b.crypto) "crypto")
    ++ (lib.optional (isBannerEnabled b.stocks) "stocks")
    ++ (lib.optional (isBannerEnabled b.weather) "weather")
    ++ (lib.optional (isBannerEnabled b.hackerNews) "news");
  enabledBannerNamesText = lib.concatStringsSep " " enabledBannerNames;

  bannerPrelude = name: ''
    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-banners"
    if [ -e "$state_dir/all.hidden" ] || [ -e "$state_dir/${name}.hidden" ]; then
      jq -cn --arg tooltip "${name}: hidden" \
        '{text:"", tooltip:$tooltip, class:"hidden"}'
      exit 0
    fi
  '';

  bannerSignals = [
    8
    9
    10
    11
    12
  ];
  bannerSignalsText = lib.concatMapStringsSep " " toString bannerSignals;

  hudWidgetNames =
    (lib.optional (isHudWidgetEnabled w.mode) "mode")
    ++ (lib.optional (isHudWidgetEnabled w.pi) "pi")
    ++ (lib.optional (isHudWidgetEnabled w.news) "news")
    ++ (lib.optional (isHudWidgetEnabled w.configIntel) "config")
    ++ (lib.optional (isHudWidgetEnabled w.agentIntel) "agents")
    ++ (lib.optional (isHudWidgetEnabled w.serviceIntel) "services");
  hudWidgetNamesText = lib.concatStringsSep " " hudWidgetNames;

  hudPrelude = name: ''
    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-widgets"
    if [ -e "$state_dir/all.hidden" ] || [ -e "$state_dir/${name}.hidden" ]; then
      jq -cn --arg tooltip "${name}: hidden" \
        '{text:"", tooltip:$tooltip, class:"hidden"}'
      exit 0
    fi
  '';

  bannerVisibilityScript = pkgs.writeShellApplication {
    name = "waybar-banner-visibility";
    runtimeInputs = with pkgs; [
      coreutils
      procps
    ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-banners"
      mkdir -p "$state_dir"

      refresh_waybar() {
        for signal in ${bannerSignalsText}; do
          pkill "-RTMIN+$signal" waybar >/dev/null 2>&1 || true
        done
      }

      action="''${1:-status}"
      shift || true
      names="$*"
      [ -n "$names" ] || names="${enabledBannerNamesText}"
      read -r -a banner_names <<< "$names"

      all_hidden() {
        for name in "''${banner_names[@]}"; do
          [ -e "$state_dir/$name.hidden" ] || return 1
        done
        return 0
      }

      case "$action" in
        hide)
          for name in "''${banner_names[@]}"; do
            touch "$state_dir/$name.hidden"
          done
          ;;
        show)
          for name in "''${banner_names[@]}"; do
            rm -f "$state_dir/$name.hidden"
          done
          rm -f "$state_dir/all.hidden"
          ;;
        toggle)
          for name in "''${banner_names[@]}"; do
            if [ -e "$state_dir/$name.hidden" ]; then
              rm -f "$state_dir/$name.hidden"
            else
              touch "$state_dir/$name.hidden"
            fi
          done
          ;;
        toggle-all)
          if all_hidden; then
            for name in "''${banner_names[@]}"; do
              rm -f "$state_dir/$name.hidden"
            done
            rm -f "$state_dir/all.hidden"
          else
            for name in "''${banner_names[@]}"; do
              touch "$state_dir/$name.hidden"
            done
          fi
          ;;
      esac

      refresh_waybar
    '';
  };

  widgetVisibilityScript = pkgs.writeShellApplication {
    name = "waybar-widget-visibility";
    runtimeInputs = [
      layoutCommand
      pkgs.coreutils
    ];
    text = ''
      # Compatibility for the existing immutable Hyprland key bindings.
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-widgets"
      rm -f "$state_dir"/*.hidden 2>/dev/null || true

      case "''${1:-status}" in
        toggle|toggle-all) waybar-layout toggle-launch ;;
        show) waybar-layout launch ;;
        hide) waybar-layout main ;;
        status) waybar-layout status ;;
        *) waybar-layout --help ;;
      esac
    '';
  };
  bannerStatusScript = pkgs.writeShellApplication {
    name = "waybar-banner-status";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-banners"
      names="${enabledBannerNamesText}"
      read -r -a banner_names <<< "$names"
      total=0
      hidden=0

      for name in "''${banner_names[@]}"; do
        total=$(( total + 1 ))
        if [ -e "$state_dir/all.hidden" ] || [ -e "$state_dir/$name.hidden" ]; then
          hidden=$(( hidden + 1 ))
        fi
      done

      if [ "$total" -eq 0 ]; then
        jq -cn '{text:"", tooltip:"feeds disabled", class:"hidden"}'
        exit 0
      fi

      visible=$(( total - hidden ))
      if [ "$visible" -eq 0 ]; then
        text="feeds off"
        cls="down"
      else
        text="feeds $visible/$total"
        cls="ok"
      fi

      tooltip="left: toggle all feeds\nmiddle: hide all feeds\nright: show all feeds"
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  hudStatusScript = pkgs.writeShellApplication {
    name = "waybar-widget-status";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/waybar-widgets"
      names="${hudWidgetNamesText}"
      read -r -a widget_names <<< "$names"
      total=0
      hidden=0

      for name in "''${widget_names[@]}"; do
        total=$(( total + 1 ))
        if [ -e "$state_dir/all.hidden" ] || [ -e "$state_dir/$name.hidden" ]; then
          hidden=$(( hidden + 1 ))
        fi
      done

      visible=$(( total - hidden ))
      if [ "$visible" -eq 0 ]; then
        cls="down"
      else
        cls="ok"
      fi

      tooltip="widgets visible: $visible/$total\nleft: toggle widgets\nmiddle: hide widgets\nright: show widgets\nSUPER+CTRL+B: toggle widgets\nSUPER+ALT+B: show widgets"
      jq -cn --arg text "HUD" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  modeBody = ''
    state=/var/lib/hb-mode/current
    mode=$(cat "$state" 2>/dev/null || /run/current-system/sw/bin/hb-mode status 2>/dev/null || echo unknown)
    mode=$(printf '%s' "$mode" | tr -cd '[:alnum:]_-')

    case "$mode" in
      study)    text="STU"; cls="ok"; role="quiet research / learning";;
      dev)      text="DEV"; cls="ok"; role="full development workstation";;
      hack)     text="HAK"; cls="warn"; role="pentest posture, VPN first";;
      work)     text="WRK"; cls="ok"; role="notifications on, lab builders quiet";;
      personal) text="PER"; cls="ok"; role="personal cloud / media / home";;
      focus)    text="FCS"; cls="ok"; role="deep focus, notifications off";;
      night)    text="NIT"; cls="warn"; role="night mode, quiet alerts";;
      server)   text="SRV"; cls="warn"; role="server posture, desktop extras reduced";;
      recon)    text="RCN"; cls="warn"; role="recon alias, VPN first";;
      *)        text="UNK"; cls="error"; role="mode state unavailable";;
    esac

    modes=$(/run/current-system/sw/bin/hb-mode list 2>/dev/null | sed -n '1,12p' || true)
    tooltip=$(printf 'mode: %s\n%s\n\nleft: cycle configured modes\nright: mode picker (wofi)' "$mode" "$role")
    [ -n "$modes" ] && tooltip="$tooltip\n\n$modes"

    jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" --arg alt "$mode" \
      '{text:$text, tooltip:$tooltip, class:$class, alt:$alt}'
  '';

  modeScript = pkgs.writeShellApplication {
    name = "waybar-mode-state";
    runtimeInputs = with pkgs; [
      jq
      gnused
      coreutils
    ];
    text = modeBody;
  };

  hudModeScript = pkgs.writeShellApplication {
    name = "waybar-hud-mode-state";
    runtimeInputs = with pkgs; [
      jq
      gnused
      coreutils
    ];
    text = ''
      ${hudPrelude "mode"}
      ${modeBody}
    '';
  };

  piHudScript = pkgs.writeShellApplication {
    name = "waybar-pi-state";
    runtimeInputs = with pkgs; [
      jq
      findutils
      coreutils
    ];
    text = ''
      ${hudPrelude "pi"}

      session_dir="${config.home.homeDirectory}/.pi/agent/sessions"
      sessions=0
      if [ -d "$session_dir" ]; then
        sessions=$(find "$session_dir" -type f -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
      fi

      if [ -x "${piBinary}" ]; then
        cls="ok"
        tooltip="Pi agent ready\nsessions: $sessions\nSUPER+CTRL+P or click: open pull-up console\nCtrl+L: model picker\nCtrl+P: cycle scoped models\n/agent: switch role"
      else
        cls="warn"
        tooltip="Pi binary not installed yet\nHome Manager activation installs @earendil-works/pi-coding-agent"
      fi

      jq -cn --arg text "PI" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  newsTileScript = pkgs.writeShellApplication {
    name = "waybar-news-tile";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
    ];
    text = ''
      export LC_ALL=C
      ${hudPrelude "news"}

      feed="${b.hackerNews.feed}"
      top=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/$feed.json" \
        | jq -r '.[0] // empty')
      if [ -z "$top" ]; then
        jq -cn '{text:"NEWS", tooltip:"news API: fetch failed", class:"error"}'
        exit 0
      fi

      item=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/item/$top.json" || echo "")
      if [ -z "$item" ] || ! echo "$item" | jq -e . >/dev/null 2>&1; then
        jq -cn '{text:"NEWS", tooltip:"news API: item fetch failed", class:"error"}'
        exit 0
      fi

      title=$(echo "$item" | jq -r '.title // "?"')
      score=$(echo "$item" | jq -r '.score // 0')
      by=$(echo "$item" | jq -r '.by // "?"')
      comments=$(echo "$item" | jq -r '.descendants // 0')
      url=$(echo "$item" | jq -r --arg id "$top" '.url // "https://news.ycombinator.com/item?id=\($id)"')
      tooltip="$title\n\nby: $by\nscore: $score\ncomments: $comments\n$url"

      jq -cn --arg text "NEWS" --arg tooltip "$tooltip" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  configIntelScript = pkgs.writeShellApplication {
    name = "waybar-config-intel";
    runtimeInputs = with pkgs; [
      jq
      git
      gnugrep
      gnused
      coreutils
    ];
    text = ''
      ${hudPrelude "config"}

      repo="/etc/nixos"
      branch=$(git -C "$repo" branch --show-current 2>/dev/null || true)
      [ -n "$branch" ] || branch=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo detached)
      head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)
      dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)
      dirty="''${dirty:-0}"
      count_matches() {
        grep -Ec "$1" "$2" 2>/dev/null || true
      }
      system_imports=$(count_matches '^[[:space:]]*\./modules/' "$repo/configuration.nix")
      home_imports=$(count_matches '^[[:space:]]*\./' "$repo/modules/home/default.nix")
      agent_imports=$(count_matches '^[[:space:]]*\./(observatory|ops|personal|knowledge)' "$repo/modules/agents/default.nix")
      mode=$(cat /var/lib/hb-mode/current 2>/dev/null || echo unknown)
      changes=$(git -C "$repo" status --short 2>/dev/null | sed -n '1,12p' || true)

      if [ "$dirty" -eq 0 ]; then
        cls="ok"
      else
        cls="warn"
      fi

      tooltip=$(printf 'repo: %s\nbranch: %s\nhead: %s\nmode: %s\nsystem imports: %s\nhome imports: %s\nagent suites imported: %s\ndirty paths: %s\n\n%s' \
        "$repo" "$branch" "$head" "$mode" "$system_imports" "$home_imports" "$agent_imports" "$dirty" "$changes")

      jq -cn --arg text "CFG" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  agentIntelScript = pkgs.writeShellApplication {
    name = "waybar-agent-intel";
    runtimeInputs = with pkgs; [
      jq
      systemd
      findutils
      gnused
      coreutils
    ];
    text = ''
      ${hudPrelude "agents"}

      module_count=$(find /etc/nixos/modules/agents -type f -name '*.nix' 2>/dev/null | wc -l | tr -d ' ')
      timers=$(systemctl list-timers --all --no-legend 'agent-*' 'obs-*' 2>/dev/null || true)
      timer_count=$(printf '%s\n' "$timers" | sed '/^$/d' | wc -l | tr -d ' ')
      failed=$(systemctl --failed --no-legend 'agent-*' 'obs-*' 2>/dev/null || true)
      failed_count=$(printf '%s\n' "$failed" | sed '/^$/d' | wc -l | tr -d ' ')
      latest="no readable observatory event bus"

      if [ -r /var/lib/observatory/events.jsonl ]; then
        latest=$(tail -8 /var/lib/observatory/events.jsonl 2>/dev/null \
          | jq -r '[.ts // .time // "", .source // .producer // "", .type // .event // ""] | @tsv' 2>/dev/null \
          | sed -n '1,8p' || true)
        [ -n "$latest" ] || latest="observatory event bus is empty"
      fi

      if [ "$failed_count" -gt 0 ]; then
        cls="down"
      elif [ "$timer_count" -gt 0 ]; then
        cls="ok"
      else
        cls="warn"
      fi

      tooltip=$(printf 'agent modules: %s\nagent/observatory timers: %s\nfailed units: %s\n\n%s\n\nlatest events:\n%s' \
        "$module_count" "$timer_count" "$failed_count" "$timers" "$latest")

      jq -cn --arg text "AGT" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  serviceIntelScript = pkgs.writeShellApplication {
    name = "waybar-service-intel";
    runtimeInputs = with pkgs; [
      jq
      systemd
      coreutils
    ];
    text = ''
      ${hudPrelude "services"}

      units="sshd.service fail2ban.service tailscaled.service caddy.service postgresql.service prometheus.service grafana.service ollama.service open-webui.service"
      ok=0
      total=0
      down=""

      for unit in $units; do
        total=$(( total + 1 ))
        if systemctl is-active --quiet "$unit"; then
          ok=$(( ok + 1 ))
        else
          down="$down ''${unit%.service}"
        fi
      done

      if [ "$ok" -eq "$total" ]; then
        cls="ok"
      elif [ "$ok" -eq 0 ]; then
        cls="down"
      else
        cls="warn"
      fi

      tooltip="critical services: $ok/$total active"
      [ -n "$down" ] && tooltip="$tooltip\ndown:$down"
      jq -cn --arg text "SVC" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  matrixScript = pkgs.writeShellApplication {
    name = "waybar-matrix-sig";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      sig=$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
      host=$(hostname)
      jq -cn --arg text "SIG $sig" --arg tooltip "host: $host\nentropy: /dev/urandom" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  keyboardScript = pkgs.writeShellApplication {
    name = "waybar-keyboard-layout";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      coreutils
    ];
    text = ''
      devices=$(hyprctl devices -j 2>/dev/null || true)
      layout=$(printf '%s' "$devices" \
        | jq -r '[.keyboards[]? | select(.main == true).active_keymap][0] // [.keyboards[]?.active_keymap][0] // empty' 2>/dev/null \
        || true)

      if [ -z "$layout" ]; then
        jq -cn '{text:"KB n/a", tooltip:"Hyprland keyboard state unavailable", class:"error"}'
        exit 0
      fi

      short=$(printf '%s' "$layout" | cut -c1-2 | tr '[:lower:]' '[:upper:]')
      jq -cn --arg text "KB $short" --arg tooltip "layout: $layout\nSUPER+Space switches all keyboards" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  localIpScript = pkgs.writeShellApplication {
    name = "waybar-local-ip";
    runtimeInputs = with pkgs; [
      jq
      iproute2
      gawk
      coreutils
    ];
    text = ''
      line=$(ip -o -4 addr show scope global \
        | awk '$2 !~ /^(tailscale0|docker|br-|veth|podman|virbr)/ { sub("/.*", "", $4); print $2" "$4; exit }')

      if [ -z "$line" ]; then
        jq -cn '{text:"lan n/a", tooltip:"no primary IPv4 address", class:"error"}'
        exit 0
      fi

      iface=$(printf '%s' "$line" | awk '{print $1}')
      ip4=$(printf '%s' "$line" | awk '{print $2}')
      jq -cn --arg text "lan $ip4" --arg tooltip "$iface $ip4" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  servicesScript = pkgs.writeShellApplication {
    name = "waybar-critical-services";
    runtimeInputs = with pkgs; [
      jq
      systemd
      coreutils
    ];
    text = ''
      units="sshd.service fail2ban.service tailscaled.service tor.service"
      ok=0
      total=0
      down=""

      for unit in $units; do
        total=$(( total + 1 ))
        if systemctl is-active --quiet "$unit"; then
          ok=$(( ok + 1 ))
        else
          down="$down ''${unit%.service}"
        fi
      done

      if [ "$ok" -eq "$total" ]; then
        cls="ok"
      else
        cls="down"
      fi

      tooltip="active: $ok/$total"
      [ -n "$down" ] && tooltip="$tooltip\ndown:$down"
      jq -cn --arg text "svc $ok/$total" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  sshScript = pkgs.writeShellApplication {
    name = "waybar-ssh-sessions";
    runtimeInputs = with pkgs; [
      jq
      iproute2
      gawk
      gnused
      coreutils
    ];
    text = ''
      sockets=$(ss -Htn 2>/dev/null | awk '$4 ~ /:22$/ { print $5 }' || true)
      count=$(printf '%s\n' "$sockets" | sed '/^$/d' | wc -l)

      if [ "$count" -eq 0 ]; then
        cls="ok"
        tooltip="no established ssh sessions"
      else
        cls="warn"
        tooltip=$(printf '%s\n' "$sockets" | sed -n '1,8p')
      fi

      jq -cn --arg text "ssh $count" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  fail2banScript = pkgs.writeShellApplication {
    name = "waybar-auth-pressure";
    runtimeInputs = with pkgs; [
      jq
      systemd
      gnugrep
      coreutils
    ];
    text = ''
      if ! systemctl is-active --quiet fail2ban.service; then
        jq -cn '{text:"auth off", tooltip:"fail2ban.service is not active", class:"down"}'
        exit 0
      fi

      failed=$(journalctl -u sshd --since '1 hour ago' --no-pager 2>/dev/null \
        | grep -Eci 'failed password|invalid user|authentication failure' || true)

      cls="ok"
      if [ "$failed" -gt 15 ]; then
        cls="down"
      elif [ "$failed" -gt 0 ]; then
        cls="warn"
      fi

      jq -cn --arg text "auth $failed/h" --arg tooltip "sshd failures in the last hour: $failed" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  tailscaleScript = pkgs.writeShellApplication {
    name = "waybar-tailscale-state";
    runtimeInputs = with pkgs; [
      jq
      tailscale
      systemd
      coreutils
    ];
    text = ''
      if ! systemctl is-active --quiet tailscaled.service; then
        jq -cn '{text:"ts off", tooltip:"tailscaled.service is not active", class:"down"}'
        exit 0
      fi

      ip4=$(tailscale ip -4 2>/dev/null | head -n 1 || true)
      if [ -z "$ip4" ]; then
        jq -cn '{text:"ts login", tooltip:"tailscaled is active but no Tailscale IPv4 was found", class:"warn"}'
        exit 0
      fi

      jq -cn --arg text "ts up" --arg tooltip "tailscale: $ip4" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  torScript = pkgs.writeShellApplication {
    name = "waybar-tor-state";
    runtimeInputs = with pkgs; [
      jq
      systemd
    ];
    text = ''
      if systemctl is-active --quiet tor.service; then
        jq -cn '{text:"onion up", tooltip:"tor.service active", class:"ok"}'
      else
        jq -cn '{text:"onion off", tooltip:"tor.service inactive", class:"down"}'
      fi
    '';
  };

  uptimeScript = pkgs.writeShellApplication {
    name = "waybar-uptime-load";
    runtimeInputs = with pkgs; [
      jq
      gnused
      gawk
      coreutils
    ];
    text = ''
      up=$(uptime -p | sed 's/^up //; s/ days/d/g; s/ day/d/g; s/ hours/h/g; s/ hour/h/g; s/ minutes/m/g; s/ minute/m/g; s/,//g')
      up=$(printf '%s' "$up" | awk '{print $1$2}')
      load=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
      jq -cn --arg text "up $up" --arg tooltip "load: $load" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  serviceGroupScript =
    {
      name,
      label,
      units,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        jq
        systemd
        coreutils
      ];
      text = ''
        units="${lib.concatStringsSep " " units}"
        ok=0
        total=0
        down=""

        for unit in $units; do
          total=$(( total + 1 ))
          if systemctl is-active --quiet "$unit"; then
            ok=$(( ok + 1 ))
          else
            down="$down ''${unit%.service}"
          fi
        done

        if [ "$ok" -eq "$total" ]; then
          cls="ok"
        elif [ "$ok" -eq 0 ]; then
          cls="down"
        else
          cls="warn"
        fi

        text="${label} $ok/$total"
        tooltip="${label}: $ok/$total active"
        [ -n "$down" ] && tooltip="$tooltip\ndown:$down"

        jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
          '{text:$text, tooltip:$tooltip, class:$class}'
      '';
    };

  identityScript = pkgs.writeShellApplication {
    name = "waybar-operator-identity";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      operator=$(id -un 2>/dev/null || echo main)
      host=$(cat /proc/sys/kernel/hostname 2>/dev/null || echo nixos-hacker-box)
      kernel=$(uname -r 2>/dev/null || echo unknown)
      jq -cn --arg text "HX" --arg tooltip "$operator@$host\nkernel: $kernel\nprofile: engineering" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  flakeScript = pkgs.writeShellApplication {
    name = "waybar-flake-state";
    runtimeInputs = with pkgs; [
      jq
      git
      gnused
      coreutils
    ];
    text = ''
      repo="/etc/nixos"
      if [ ! -d "$repo/.git" ]; then
        jq -cn '{text:"git n/a", tooltip:"/etc/nixos is not a git checkout", class:"error"}'
        exit 0
      fi

      branch=$(git -C "$repo" branch --show-current 2>/dev/null || true)
      [ -n "$branch" ] || branch=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo detached)
      head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)
      dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)
      dirty="''${dirty:-0}"
      short_branch=$(printf '%s' "$branch" | cut -c1-8)
      changes=$(git -C "$repo" status --short 2>/dev/null | sed -n '1,12p' || true)

      if [ "$dirty" -eq 0 ]; then
        cls="ok"
        text="git $short_branch"
      else
        cls="warn"
        text="git $dirty"
      fi

      tooltip=$(printf 'repo: %s\nbranch: %s\nhead: %s\ndirty paths: %s\n\n%s' "$repo" "$branch" "$head" "$dirty" "$changes")
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  generationScript = pkgs.writeShellApplication {
    name = "waybar-nixos-generation";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      version="unknown"
      if [ -x /run/current-system/sw/bin/nixos-version ]; then
        version=$(/run/current-system/sw/bin/nixos-version 2>/dev/null || echo unknown)
      fi

      version_short=$(printf '%s' "$version" | cut -d. -f1,2)
      current=$(readlink /run/current-system 2>/dev/null || true)
      booted=$(readlink /run/booted-system 2>/dev/null || true)

      if [ -n "$current" ] && [ "$current" = "$booted" ]; then
        cls="ok"
        drift="booted generation matches current system"
        text="gen ok"
      else
        cls="warn"
        drift="current system differs from booted system or state is unknown"
        text="gen drift"
      fi

      tooltip=$(printf 'NixOS: %s\n%s\n\ncurrent: %s\nbooted:  %s' "$version" "$drift" "$current" "$booted")
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" --arg version "$version_short" \
        '{text:$text, tooltip:$tooltip, class:$class, alt:$version}'
    '';
  };

  storeScript = pkgs.writeShellApplication {
    name = "waybar-nix-store-pressure";
    runtimeInputs = with pkgs; [
      jq
      gawk
      coreutils
    ];
    text = ''
      line=$(df -P /nix/store 2>/dev/null | awk 'NR==2 { print $2" "$3" "$4" "$5" "$6 }' || true)
      if [ -z "$line" ]; then
        jq -cn '{text:"nix n/a", tooltip:"cannot read /nix/store filesystem usage", class:"error"}'
        exit 0
      fi

      read -r _blocks _used avail pct _mount <<< "$line"
      used_pct=$(printf '%s' "$pct" | tr -d '%')
      used_pct="''${used_pct:-0}"
      free_h=$(df -hP /nix/store 2>/dev/null | awk 'NR==2 {print $4}' || echo n/a)

      if [ "$used_pct" -ge 90 ]; then
        cls="down"
      elif [ "$used_pct" -ge 80 ]; then
        cls="warn"
      else
        cls="ok"
      fi

      tooltip="store free: $free_h\nblocks available: $avail\nused: $pct"
      jq -cn --arg text "nix $pct" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  portsScript = pkgs.writeShellApplication {
    name = "waybar-listening-ports";
    runtimeInputs = with pkgs; [
      jq
      iproute2
      gawk
      gnused
      coreutils
    ];
    text = ''
      ports=$(ss -H -ltn 2>/dev/null \
        | awk '{ print $4 }' \
        | sed -E 's/.*:([0-9]+)$/\1/' \
        | sort -n \
        | uniq || true)
      count=$(printf '%s\n' "$ports" | sed '/^$/d' | wc -l | tr -d ' ')
      top_ports=$(printf '%s\n' "$ports" | sed '/^$/d' | sed -n '1,28p' | paste -sd ' ' - || true)

      if [ "$count" -gt 70 ]; then
        cls="down"
      elif [ "$count" -gt 35 ]; then
        cls="warn"
      else
        cls="ok"
      fi

      tooltip=$(printf 'listening tcp ports: %s\n\n%s' "$count" "$top_ports")
      jq -cn --arg text "tcp $count" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  containersScript = pkgs.writeShellApplication {
    name = "waybar-container-state";
    runtimeInputs = with pkgs; [
      jq
      podman
      docker_29
      gnused
      coreutils
    ];
    text = ''
      podman_names=$(podman ps --format '{{.Names}}' 2>/dev/null || true)
      docker_names=$(docker ps --format '{{.Names}}' 2>/dev/null || true)
      podman_count=$(printf '%s\n' "$podman_names" | sed '/^$/d' | wc -l | tr -d ' ')
      docker_count=$(printf '%s\n' "$docker_names" | sed '/^$/d' | wc -l | tr -d ' ')
      podman_count="''${podman_count:-0}"
      docker_count="''${docker_count:-0}"
      total=$(( podman_count + docker_count ))

      if [ "$total" -eq 0 ]; then
        cls="warn"
      else
        cls="ok"
      fi

      tooltip=$(printf 'podman running: %s\n%s\n\ndocker running: %s\n%s' "$podman_count" "$podman_names" "$docker_count" "$docker_names")
      jq -cn --arg text "ctr $total" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  virtScript = pkgs.writeShellApplication {
    name = "waybar-virt-state";
    runtimeInputs = with pkgs; [
      jq
      libvirt
      systemd
      gnused
      coreutils
    ];
    text = ''
      active=0
      if systemctl is-active --quiet libvirtd.service || systemctl is-active --quiet virtqemud.service; then
        active=1
      fi

      if [ "$active" -eq 0 ]; then
        jq -cn '{text:"vm off", tooltip:"libvirt is not active", class:"warn"}'
        exit 0
      fi

      all=$(virsh -c qemu:///system list --all --name 2>/dev/null || true)
      running=$(virsh -c qemu:///system list --name 2>/dev/null || true)
      all_count=$(printf '%s\n' "$all" | sed '/^$/d' | wc -l | tr -d ' ')
      running_count=$(printf '%s\n' "$running" | sed '/^$/d' | wc -l | tr -d ' ')
      all_count="''${all_count:-0}"
      running_count="''${running_count:-0}"

      tooltip=$(printf 'running: %s/%s\n\n%s' "$running_count" "$all_count" "$all")
      jq -cn --arg text "vm $running_count/$all_count" --arg tooltip "$tooltip" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  backupScript = pkgs.writeShellApplication {
    name = "waybar-backup-state";
    runtimeInputs = with pkgs; [
      jq
      systemd
      gawk
      coreutils
    ];
    text = ''
      timer=$(systemctl is-active restic-backups-offsite.timer 2>/dev/null || true)
      verify=$(systemctl is-active restic-verify.timer 2>/dev/null || true)
      result=$(systemctl show restic-backups-offsite.service -p Result --value 2>/dev/null || true)
      next=$(systemctl list-timers --all --no-pager --plain restic-backups-offsite.timer 2>/dev/null \
        | awk 'NR==2 {print $1" "$2" "$3}' || true)
      [ -n "$result" ] || result="unknown"
      [ -n "$next" ] || next="n/a"

      if [ "$result" = "failed" ]; then
        cls="down"
        text="bk fail"
      elif [ "$timer" = "active" ]; then
        cls="ok"
        text="bk ok"
      else
        cls="warn"
        text="bk off"
      fi

      tooltip="backup timer: $timer\nverify timer: $verify\nlast result: $result\nnext: $next"
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  agentsScript = pkgs.writeShellApplication {
    name = "waybar-agent-state";
    runtimeInputs = with pkgs; [
      jq
      systemd
      gnused
      coreutils
    ];
    text = ''
      timers=$(systemctl list-timers --all --no-legend 'agent-*' 'obs-*' 2>/dev/null || true)
      active_count=$(printf '%s\n' "$timers" | sed '/^$/d' | wc -l | tr -d ' ')
      failed=$(systemctl --failed --no-legend 'agent-*' 'obs-*' 2>/dev/null || true)
      failed_count=$(printf '%s\n' "$failed" | sed '/^$/d' | wc -l | tr -d ' ')
      active_count="''${active_count:-0}"
      failed_count="''${failed_count:-0}"

      if [ "$failed_count" -gt 0 ]; then
        cls="down"
      elif [ "$active_count" -gt 0 ]; then
        cls="ok"
      else
        cls="warn"
      fi

      tooltip=$(printf 'agent/observatory timers: %s\n\n%s\n\nfailed:\n%s' "$active_count" "$timers" "$failed")
      jq -cn --arg text "agt $active_count" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  cloudScript = serviceGroupScript {
    name = "waybar-cloud-state";
    label = "cld";
    units = [
      "phpfpm-nextcloud.service"
      "nginx.service"
      "postgresql.service"
      "redis-nextcloud.service"
      "forgejo.service"
      "caddy.service"
    ];
  };

  hubScript = serviceGroupScript {
    name = "waybar-hub-state";
    label = "hub";
    units = [
      "miniflux.service"
      "vaultwarden.service"
      "vikunja.service"
      "audiobookshelf.service"
      "navidrome.service"
      "uptime-kuma.service"
      "trilium-server.service"
    ];
  };

  nasScript = serviceGroupScript {
    name = "waybar-nas-state";
    label = "nas";
    units = [
      "smbd.service"
      "syncthing.service"
    ];
  };

  observabilityScript = serviceGroupScript {
    name = "waybar-observability-state";
    label = "obs";
    units = [
      "prometheus.service"
      "grafana.service"
      "loki.service"
      "victoriametrics.service"
      "ntfy-sh.service"
    ];
  };

  aiScript = serviceGroupScript {
    name = "waybar-ai-state";
    label = "ai";
    units = [
      "ollama.service"
      "open-webui.service"
      "home-assistant.service"
      "podman-qdrant.service"
      "podman-piper-tts.service"
      "podman-searxng.service"
    ];
  };

  # --------- Ticker scripts ------------------------------------------------

  cryptoScript = pkgs.writeShellApplication {
    name = "waybar-crypto";
    runtimeInputs = with pkgs; [
      curl
      jq
      gawk
      coreutils
    ];
    text = ''
      export LC_ALL=C
      ${bannerPrelude "crypto"}

      ids="${lib.concatStringsSep "," b.crypto.symbols}"
      resp=$(curl -sf --max-time 8 \
        "https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=usd&include_24hr_change=true" \
        || echo "")

      if [ -z "$resp" ] || ! echo "$resp" | jq -e . >/dev/null 2>&1; then
        jq -cn '{text:"₿ n/a", tooltip:"crypto: fetch failed", class:"error"}'
        exit 0
      fi

      text=""
      tooltip=""
      cls="ok"
      IFS=',' read -r -a coin_ids <<< "$ids"

      for id in "''${coin_ids[@]}"; do
        price=$(echo "$resp" | jq -r --arg id "$id" '.[$id].usd // empty')
        change=$(echo "$resp" | jq -r --arg id "$id" '.[$id].usd_24h_change // 0')
        [ -z "$price" ] && continue

        case "$id" in
          bitcoin)      sym="₿"; ;;
          ethereum)     sym="Ξ"; ;;
          solana)       sym="◎"; ;;
          cardano)      sym="₳"; ;;
          *)            sym=$(echo "$id" | cut -c1-3 | tr '[:lower:]' '[:upper:]') ;;
        esac

        arrow=$(awk -v c="$change" 'BEGIN{ if(c+0>=0) print "▲"; else print "▼" }')
        # short price: strip decimals over $100
        short=$(awk -v p="$price" 'BEGIN{ if(p+0>=100) printf "%.0f", p; else printf "%.2f", p }')
        chg=$(printf "%.1f" "$change")

        text="$text $sym $short $arrow"
        tooltip="$tooltip$sym  \$$price   ''${chg}% 24h\n"

        # if any ticker is negative, class = down
        neg=$(awk -v c="$change" 'BEGIN{ print (c+0<0) }')
        [ "$neg" = "1" ] && cls="down"
      done

      text="''${text# }"
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  hnScript = pkgs.writeShellApplication {
    name = "waybar-hn";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
    ];
    text = ''
      export LC_ALL=C
      ${bannerPrelude "news"}

      feed="${b.hackerNews.feed}"
      max_len="${toString b.hackerNews.maxTitleLength}"
      top=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/$feed.json" \
        | jq -r '.[0] // empty')
      if [ -z "$top" ]; then
        jq -cn '{text:" n/a", tooltip:"HN: fetch failed", class:"error"}'
        exit 0
      fi

      item=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/item/$top.json")
      if [ -z "$item" ]; then
        jq -cn '{text:" n/a", tooltip:"HN: item fetch failed", class:"error"}'
        exit 0
      fi

      title=$(echo "$item" | jq -r '.title // "?"')
      score=$(echo "$item" | jq -r '.score // 0')
      by=$(echo "$item" | jq -r '.by // "?"')
      comments=$(echo "$item" | jq -r '.descendants // 0')
      url=$(echo "$item" | jq -r --arg id "$top" '.url // "https://news.ycombinator.com/item?id=\($id)"')

      short=$(printf '%s' "$title" | cut -c "1-$max_len")
      [ "$(printf '%s' "$title" | wc -m)" -gt "$max_len" ] && short="$short…"

      text="HN $short [$score↑]"
      tooltip="$title\n\n by $by  ·  $score points  ·  $comments comments\n$url"
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  hnOpenScript = pkgs.writeShellApplication {
    name = "waybar-hn-open";
    runtimeInputs = with pkgs; [
      curl
      jq
      xdg-utils
      coreutils
    ];
    text = ''
      feed="${b.hackerNews.feed}"
      top=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/$feed.json" \
        | jq -r '.[0] // empty')
      [ -z "$top" ] && exit 0
      url=$(curl -sf --max-time 8 "https://hacker-news.firebaseio.com/v0/item/$top.json" \
        | jq -r --arg id "$top" '.url // "https://news.ycombinator.com/item?id=\($id)"')
      xdg-open "$url" >/dev/null 2>&1 &
    '';
  };

  weatherScript = pkgs.writeShellApplication {
    name = "waybar-weather";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
    ];
    text = ''
      export LC_ALL=C
      ${bannerPrelude "weather"}

      loc="${b.weather.location}"
      resp=$(curl -sf --max-time 8 "https://wttr.in/$loc?format=j1" || echo "")
      if [ -z "$resp" ] || ! echo "$resp" | jq -e . >/dev/null 2>&1; then
        jq -cn '{text:" n/a", tooltip:"weather: fetch failed", class:"error"}'
        exit 0
      fi

      temp=$(echo "$resp" | jq -r '.current_condition[0].temp_C // "?"')
      feels=$(echo "$resp" | jq -r '.current_condition[0].FeelsLikeC // "?"')
      cond=$(echo "$resp" | jq -r '.current_condition[0].weatherDesc[0].value // ""')
      humidity=$(echo "$resp" | jq -r '.current_condition[0].humidity // "?"')
      wind=$(echo "$resp" | jq -r '.current_condition[0].windspeedKmph // "?"')
      area=$(echo "$resp" | jq -r '.nearest_area[0].areaName[0].value // ""')
      region=$(echo "$resp" | jq -r '.nearest_area[0].region[0].value // ""')

      icon="WX"
      case "$cond" in
        *Clear*|*Sunny*)              icon="SUN" ;;
        *Cloud*|*Overcast*)           icon="CLD" ;;
        *Rain*|*Drizzle*|*Shower*)    icon="RAN" ;;
        *Snow*|*Sleet*)               icon="SNW" ;;
        *Thunder*)                    icon="THR" ;;
        *Mist*|*Fog*|*Haze*)          icon="FOG" ;;
      esac

      text="$icon ''${temp}°C"
      tooltip="$area, $region\n$cond\ntemp: ''${temp}°C (feels ''${feels}°C)\nhumidity: ''${humidity}%\nwind: ''${wind} km/h"
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "ok" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  # Stooq public CSV endpoint — no auth for quote snapshots.
  # One HTTP call covers the configured symbol list.
  stocksScript = pkgs.writeShellApplication {
    name = "waybar-stocks";
    runtimeInputs = with pkgs; [
      curl
      jq
      gawk
      coreutils
    ];
    text = ''
      export LC_ALL=C
      ${bannerPrelude "stocks"}

      symbols_raw="${lib.concatStringsSep " " b.stocks.symbols}"
      symbols_stooq=""
      read -r -a stock_symbols <<< "$symbols_raw"

      for raw in "''${stock_symbols[@]}"; do
        sym_lc=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
        case "$sym_lc" in
          *.*|^*|*usd) stooq_sym="$sym_lc" ;;
          *)           stooq_sym="''${sym_lc}.us" ;;
        esac
        symbols_stooq="$symbols_stooq,$stooq_sym"
      done

      symbols_stooq="''${symbols_stooq#,}"
      resp=$(curl -sf --max-time 8 \
        "https://stooq.com/q/l/?s=$symbols_stooq&f=sd2t2ohlcv&h&e=csv" \
        || echo "")

      if [ -z "$resp" ]; then
        jq -cn '{text:" n/a", tooltip:"stocks: fetch failed", class:"error"}'
        exit 0
      fi

      text=""
      tooltip=""
      cls="ok"

      while IFS=',' read -r sym _date _time open _high _low close _volume; do
        [ -z "$sym" ] && continue
        [ "$sym" = "Symbol" ] && continue
        [ "$close" = "N/D" ] && continue

        short_sym="''${sym%.US}"
        short_sym="''${short_sym%.us}"
        short_sym=$(printf '%s' "$short_sym" | tr '[:lower:]' '[:upper:]')
        change=$(awk -v o="$open" -v c="$close" \
          'BEGIN{ if(o+0==0) printf "0.00"; else printf "%.2f", (c-o)/o*100 }')
        arrow=$(awk -v c="$change" 'BEGIN{ if(c+0>=0) print "▲"; else print "▼" }')
        price=$(printf "%.2f" "$close")

        text="$text $short_sym $price$arrow"
        tooltip="$tooltip$short_sym  $price  ''${change}%\n"

        neg=$(awk -v c="$change" 'BEGIN{ print (c+0<0) }')
        [ "$neg" = "1" ] && cls="down"
      done <<< "$resp"

      text="''${text# }"
      if [ -z "$text" ]; then
        jq -cn '{text:" n/a", tooltip:"stocks: fetch failed", class:"error"}'
        exit 0
      fi

      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$cls" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  # --------- Module wiring -------------------------------------------------

  tickerModules =
    (lib.optional (isBannerEnabled b.crypto) "custom/crypto")
    ++ (lib.optional (isBannerEnabled b.stocks) "custom/stocks")
    ++ (lib.optional (isBannerEnabled b.weather) "custom/weather")
    ++ (lib.optional (isBannerEnabled b.hackerNews) "custom/hn");
  bannerControlModules = lib.optional (
    b.enable && b.dismissable && enabledBannerNames != [ ]
  ) "custom/banner-toggle";

  mainLeftModules = [
    "hyprland/workspaces"
    "hyprland/submap"
  ];

  launchModules =
    (lib.optional (isHudWidgetEnabled w.mode) "custom/hud-mode")
    ++ (lib.optional (isHudWidgetEnabled w.pi) "custom/hud-pi")
    ++ (lib.optional (isHudWidgetEnabled w.news) "custom/hud-news")
    ++ (lib.optional (isHudWidgetEnabled w.configIntel) "custom/hud-config")
    ++ (lib.optional (isHudWidgetEnabled w.agentIntel) "custom/hud-agents")
    ++ (lib.optional (isHudWidgetEnabled w.serviceIntel) "custom/hud-services");

  opsLeftModules = [
    "custom/operator"
  ]
  ++ (lib.optional w.mode.enable "custom/mode")
  ++ (lib.optional (isOpsWidgetEnabled w.services) "custom/services")
  ++ (lib.optional (isOpsWidgetEnabled w.ssh) "custom/ssh")
  ++ (lib.optional (isOpsWidgetEnabled w.fail2ban) "custom/fail2ban")
  ++ (lib.optional (isOpsWidgetEnabled w.tailscale) "custom/tailscale")
  ++ (lib.optional (isOpsWidgetEnabled w.tor) "custom/tor")
  ++ (lib.optional (isOpsWidgetEnabled w.matrix) "custom/matrix")
  ++ (lib.optional (isOpsWidgetEnabled w.keyboard) "custom/keyboard");
  opsRightModules =
    (lib.optional (isOpsWidgetEnabled w.localIp) "custom/local-ip")
    ++ (lib.optional (isOpsWidgetEnabled w.uptime) "custom/uptime")
    ++ [
      "clock#utc"
    ];

  spineTopModules =
    (lib.optional (isSpineWidgetEnabled w.identity) "custom/identity")
    ++ (lib.optional (isSpineWidgetEnabled w.flake) "custom/flake")
    ++ (lib.optional (isSpineWidgetEnabled w.generation) "custom/generation")
    ++ (lib.optional (isSpineWidgetEnabled w.store) "custom/store");
  spineCenterModules =
    (lib.optional (isSpineWidgetEnabled w.cloud) "custom/cloud")
    ++ (lib.optional (isSpineWidgetEnabled w.nas) "custom/nas")
    ++ (lib.optional (isSpineWidgetEnabled w.hub) "custom/hub")
    ++ (lib.optional (isSpineWidgetEnabled w.observability) "custom/observability")
    ++ (lib.optional (isSpineWidgetEnabled w.ai) "custom/ai")
    ++ (lib.optional (isSpineWidgetEnabled w.agents) "custom/agents")
    ++ (lib.optional (isSpineWidgetEnabled w.backup) "custom/backup");
  spineBottomModules =
    (lib.optional (isSpineWidgetEnabled w.ports) "custom/ports")
    ++ (lib.optional (isSpineWidgetEnabled w.containers) "custom/containers")
    ++ (lib.optional (isSpineWidgetEnabled w.virt) "custom/virt");

  customModules =
    lib.optionalAttrs w.mode.enable {
      "custom/mode" = {
        inherit (w.mode) interval;
        exec = "${modeScript}/bin/waybar-mode-state";
        return-type = "json";
        tooltip = true;
        signal = 13;
        on-click = "hb-mode-cycle";
        on-click-right = "hb-mode-pick";
      };
    }
    // lib.optionalAttrs (isBannerEnabled b.crypto) {
      "custom/crypto" = {
        inherit (b.crypto) interval;
        exec = "${cryptoScript}/bin/waybar-crypto";
        return-type = "json";
        tooltip = true;
        signal = 8;
        on-click = "${pkgs.xdg-utils}/bin/xdg-open https://www.coingecko.com >/dev/null 2>&1 &";
        on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle crypto";
      };
    }
    // lib.optionalAttrs (isBannerEnabled b.stocks) {
      "custom/stocks" = {
        inherit (b.stocks) interval;
        exec = "${stocksScript}/bin/waybar-stocks";
        return-type = "json";
        tooltip = true;
        signal = 9;
        on-click = "${pkgs.xdg-utils}/bin/xdg-open https://stooq.com >/dev/null 2>&1 &";
        on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle stocks";
      };
    }
    // lib.optionalAttrs (isBannerEnabled b.weather) {
      "custom/weather" = {
        inherit (b.weather) interval;
        exec = "${weatherScript}/bin/waybar-weather";
        return-type = "json";
        tooltip = true;
        signal = 10;
        on-click = "${pkgs.xdg-utils}/bin/xdg-open https://wttr.in >/dev/null 2>&1 &";
        on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle weather";
      };
    }
    // lib.optionalAttrs (isBannerEnabled b.hackerNews) {
      "custom/hn" = {
        inherit (b.hackerNews) interval;
        exec = "${hnScript}/bin/waybar-hn";
        return-type = "json";
        tooltip = true;
        signal = 11;
        on-click = "${hnOpenScript}/bin/waybar-hn-open";
        on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle news";
      };
    }
    // lib.optionalAttrs (b.enable && b.dismissable && enabledBannerNames != [ ]) {
      "custom/banner-toggle" = {
        interval = 5;
        exec = "${bannerStatusScript}/bin/waybar-banner-status";
        return-type = "json";
        tooltip = true;
        signal = 12;
        on-click = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle-all ${enabledBannerNamesText}";
        on-click-middle = "${bannerVisibilityScript}/bin/waybar-banner-visibility hide ${enabledBannerNamesText}";
        on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility show ${enabledBannerNamesText}";
      };
    };

  hudCustomModules = {
    "custom/hud-toggle" = {
      interval = 5;
      exec = "${hudStatusScript}/bin/waybar-widget-status";
      return-type = "json";
      tooltip = true;
      signal = 19;
      on-click = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle-all ${hudWidgetNamesText}";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility hide ${hudWidgetNamesText}";
      on-click-right = "${widgetVisibilityScript}/bin/waybar-widget-visibility show ${hudWidgetNamesText}";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.mode) {
    "custom/hud-mode" = {
      inherit (w.mode) interval;
      exec = "${hudModeScript}/bin/waybar-hud-mode-state";
      return-type = "json";
      tooltip = true;
      signal = 13;
      on-click = "hb-mode-cycle";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle mode";
      on-click-right = "hb-mode-pick";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.pi) {
    "custom/hud-pi" = {
      inherit (w.pi) interval;
      exec = "${piHudScript}/bin/waybar-pi-state";
      return-type = "json";
      tooltip = true;
      signal = 14;
      on-click = "hb-pi";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle pi";
      on-click-right = "hb-command-center";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.news) {
    "custom/hud-news" = {
      inherit (w.news) interval;
      exec = "${newsTileScript}/bin/waybar-news-tile";
      return-type = "json";
      tooltip = true;
      signal = 15;
      on-click = "${hnOpenScript}/bin/waybar-hn-open";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle news";
      on-click-right = "${bannerVisibilityScript}/bin/waybar-banner-visibility toggle news";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.configIntel) {
    "custom/hud-config" = {
      inherit (w.configIntel) interval;
      exec = "${configIntelScript}/bin/waybar-config-intel";
      return-type = "json";
      tooltip = true;
      signal = 16;
      on-click = "hb-agent-deck";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle config";
      on-click-right = "hb-command-center";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.agentIntel) {
    "custom/hud-agents" = {
      inherit (w.agentIntel) interval;
      exec = "${agentIntelScript}/bin/waybar-agent-intel";
      return-type = "json";
      tooltip = true;
      signal = 17;
      on-click = "hb-agent-deck";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle agents";
      on-click-right = "hb-command-center";
    };
  }
  // lib.optionalAttrs (isHudWidgetEnabled w.serviceIntel) {
    "custom/hud-services" = {
      inherit (w.serviceIntel) interval;
      exec = "${serviceIntelScript}/bin/waybar-service-intel";
      return-type = "json";
      tooltip = true;
      signal = 18;
      on-click = "hb-audit-deck";
      on-click-middle = "${widgetVisibilityScript}/bin/waybar-widget-visibility toggle services";
      on-click-right = "hb-command-center";
    };
  };

  opsCustomModules = {
    "custom/operator" = {
      exec = "${pkgs.jq}/bin/jq -cn --arg text 'HX' --arg tooltip 'SUPER+CTRL+P pi\\nSUPER+O ops deck\\nSUPER+N net deck\\nSUPER+X security deck\\nSUPER+I infra deck\\nSUPER+A audit deck\\nSUPER+U lab deck\\nSUPER+Z scratch\\nSUPER+CTRL+V clipboard' --arg class ok '{text:$text, tooltip:$tooltip, class:$class}'";
      return-type = "json";
      interval = 3600;
      tooltip = true;
      on-click = "hb-ops-deck";
    };
  }
  // lib.optionalAttrs w.mode.enable {
    "custom/mode" = {
      inherit (w.mode) interval;
      exec = "${modeScript}/bin/waybar-mode-state";
      return-type = "json";
      tooltip = true;
      signal = 13;
      on-click = "hb-mode-cycle";
      on-click-right = "hb-mode-pick";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.matrix) {
    "custom/matrix" = {
      inherit (w.matrix) interval;
      exec = "${matrixScript}/bin/waybar-matrix-sig";
      return-type = "json";
      tooltip = true;
      on-click = "hb-scratch-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.keyboard) {
    "custom/keyboard" = {
      inherit (w.keyboard) interval;
      exec = "${keyboardScript}/bin/waybar-keyboard-layout";
      return-type = "json";
      tooltip = true;
      on-click = "hb-switch-layout";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.services) {
    "custom/services" = {
      inherit (w.services) interval;
      exec = "${servicesScript}/bin/waybar-critical-services";
      return-type = "json";
      tooltip = true;
      on-click = "hb-sec-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.ssh) {
    "custom/ssh" = {
      inherit (w.ssh) interval;
      exec = "${sshScript}/bin/waybar-ssh-sessions";
      return-type = "json";
      tooltip = true;
      on-click = "hb-sec-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.fail2ban) {
    "custom/fail2ban" = {
      inherit (w.fail2ban) interval;
      exec = "${fail2banScript}/bin/waybar-auth-pressure";
      return-type = "json";
      tooltip = true;
      on-click = "hb-sec-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.tailscale) {
    "custom/tailscale" = {
      inherit (w.tailscale) interval;
      exec = "${tailscaleScript}/bin/waybar-tailscale-state";
      return-type = "json";
      tooltip = true;
      on-click = "hb-net-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.tor) {
    "custom/tor" = {
      inherit (w.tor) interval;
      exec = "${torScript}/bin/waybar-tor-state";
      return-type = "json";
      tooltip = true;
      on-click = "hb-sec-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.localIp) {
    "custom/local-ip" = {
      inherit (w.localIp) interval;
      exec = "${localIpScript}/bin/waybar-local-ip";
      return-type = "json";
      tooltip = true;
      on-click = "hb-net-deck";
    };
  }
  // lib.optionalAttrs (isOpsWidgetEnabled w.uptime) {
    "custom/uptime" = {
      inherit (w.uptime) interval;
      exec = "${uptimeScript}/bin/waybar-uptime-load";
      return-type = "json";
      tooltip = true;
      on-click = "hb-ops-deck";
    };
  };

  spineCustomModules =
    lib.optionalAttrs (isSpineWidgetEnabled w.identity) {
      "custom/identity" = {
        inherit (w.identity) interval;
        exec = "${identityScript}/bin/waybar-operator-identity";
        return-type = "json";
        tooltip = true;
        on-click = "hb-infra-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.flake) {
      "custom/flake" = {
        inherit (w.flake) interval;
        exec = "${flakeScript}/bin/waybar-flake-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-infra-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.generation) {
      "custom/generation" = {
        inherit (w.generation) interval;
        exec = "${generationScript}/bin/waybar-nixos-generation";
        return-type = "json";
        tooltip = true;
        on-click = "hb-infra-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.store) {
      "custom/store" = {
        inherit (w.store) interval;
        exec = "${storeScript}/bin/waybar-nix-store-pressure";
        return-type = "json";
        tooltip = true;
        on-click = "hb-infra-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.cloud) {
      "custom/cloud" = {
        inherit (w.cloud) interval;
        exec = "${cloudScript}/bin/waybar-cloud-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.nas) {
      "custom/nas" = {
        inherit (w.nas) interval;
        exec = "${nasScript}/bin/waybar-nas-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.hub) {
      "custom/hub" = {
        inherit (w.hub) interval;
        exec = "${hubScript}/bin/waybar-hub-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.observability) {
      "custom/observability" = {
        inherit (w.observability) interval;
        exec = "${observabilityScript}/bin/waybar-observability-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.ai) {
      "custom/ai" = {
        inherit (w.ai) interval;
        exec = "${aiScript}/bin/waybar-ai-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.agents) {
      "custom/agents" = {
        inherit (w.agents) interval;
        exec = "${agentsScript}/bin/waybar-agent-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.backup) {
      "custom/backup" = {
        inherit (w.backup) interval;
        exec = "${backupScript}/bin/waybar-backup-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-audit-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.ports) {
      "custom/ports" = {
        inherit (w.ports) interval;
        exec = "${portsScript}/bin/waybar-listening-ports";
        return-type = "json";
        tooltip = true;
        on-click = "hb-net-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.containers) {
      "custom/containers" = {
        inherit (w.containers) interval;
        exec = "${containersScript}/bin/waybar-container-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-lab-deck";
      };
    }
    // lib.optionalAttrs (isSpineWidgetEnabled w.virt) {
      "custom/virt" = {
        inherit (w.virt) interval;
        exec = "${virtScript}/bin/waybar-virt-state";
        return-type = "json";
        tooltip = true;
        on-click = "hb-lab-deck";
      };
    };

  layoutOrder = [
    "main"
    "ops"
    "infra"
    "intel"
    "launch"
  ];
  layoutOrderText = lib.concatStringsSep " " layoutOrder;

  layoutStatusScript = pkgs.writeShellApplication {
    name = "waybar-layout-state";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
      layout=$(cat "$state_dir/layout" 2>/dev/null || echo main)

      case "$layout" in
        main)   text="[ MAIN ]";  role="desktop telemetry" ;;
        ops)    text="[ OPS ]";   role="security and network mesh" ;;
        infra)  text="[ INFRA ]"; role="NixOS and service fabric" ;;
        intel)  text="[ INTEL ]"; role="external intelligence feeds" ;;
        launch) text="[ DECK ]";  role="operator launch controls" ;;
        *)      layout="main"; text="[ MAIN ]"; role="desktop telemetry" ;;
      esac

      tooltip=$(printf '%s\n\nleft / wheel up: next layout\nwheel down: previous layout\nright: layout menu\n\nwaybar-layout main|ops|infra|intel|launch' "$role")
      jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$layout" \
        '{text:$text, tooltip:$tooltip, class:$class}'
    '';
  };

  layoutCommand = pkgs.writeShellApplication {
    name = "waybar-layout";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      wofi
    ];
    text = ''
      profiles=( ${layoutOrderText} )
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
      state_file="$state_dir/layout"
      mkdir -p "$state_dir"

      current=$(cat "$state_file" 2>/dev/null || echo main)
      case "$current" in
        main|ops|infra|intel|launch) ;;
        *) current=main ;;
      esac

      action="''${1:-status}"
      case "$action" in
        status)
          printf '%s\n' "$current"
          exit 0
          ;;
        menu)
          action=$(printf '%s\n' "''${profiles[@]}" \
            | wofi --dmenu --prompt 'waybar layout' || true)
          [ -n "$action" ] || exit 0
          ;;
        next|previous)
          index=0
          for i in "''${!profiles[@]}"; do
            if [ "''${profiles[$i]}" = "$current" ]; then
              index=$i
              break
            fi
          done
          if [ "$action" = next ]; then
            index=$(( (index + 1) % ''${#profiles[@]} ))
          else
            index=$(( (index - 1 + ''${#profiles[@]}) % ''${#profiles[@]} ))
          fi
          action="''${profiles[$index]}"
          ;;
        toggle-launch)
          if [ "$current" = launch ]; then
            action=main
          else
            action=launch
          fi
          ;;
        help|-h|--help)
          printf '%s\n' \
            'usage: waybar-layout <main|ops|infra|intel|launch|next|previous|menu|status>' \
            '  main    workspaces, focused window and desktop telemetry' \
            '  ops     security, sessions, VPN/Tor, LAN, uptime and UTC' \
            '  infra   NixOS, services, backup, containers and virtualisation' \
            '  intel   weather, market and Hacker News feeds when enabled' \
            '  launch  Pi, agent, configuration and service controls'
          exit 0
          ;;
      esac

      case "$action" in
        main|ops|infra|intel|launch) ;;
        *)
          printf 'waybar-layout: unknown layout: %s\n' "$action" >&2
          exit 2
          ;;
      esac

      printf '%s\n' "$action" > "$state_file.tmp"
      mv "$state_file.tmp" "$state_file"
      systemctl --user --no-block restart waybar.service
    '';
  };

  allCustomModules =
    customModules
    // hudCustomModules
    // opsCustomModules
    // spineCustomModules
    // {
      "custom/layout" = {
        exec = "${layoutStatusScript}/bin/waybar-layout-state";
        return-type = "json";
        interval = 2;
        tooltip = true;
        on-click = "${layoutCommand}/bin/waybar-layout next";
        on-click-right = "${layoutCommand}/bin/waybar-layout menu";
        on-scroll-up = "${layoutCommand}/bin/waybar-layout next";
        on-scroll-down = "${layoutCommand}/bin/waybar-layout previous";
      };
    };

  commonBarConfig = {
    layer = "top";
    position = "top";
    inherit (bar) height;
    margin-top = bar.margin;
    margin-left = bar.margin;
    margin-right = bar.margin;
    spacing = 3;

    "hyprland/workspaces" = {
      format = "{icon}";
      on-click = "activate";
      format-icons = {
        "1" = "1";
        "2" = "2";
        "3" = "3";
        "4" = "4";
        "5" = "5";
        "6" = "6";
        "7" = "7";
        "8" = "8";
        "9" = "9";
        "10" = "10";
      };
    };

    "hyprland/window" = {
      format = "{}";
      max-length = 60;
      separate-outputs = true;
      rewrite = {
        "(.*) - Mozilla Firefox" = " $1";
        "(.*) - VSCodium" = "󰨞 $1";
        "(.*) — Kitty" = " $1";
        "" = "⌁ idle";
      };
    };

    network = {
      format-wifi = "󰤨 {signalStrength}%";
      format-ethernet = "󰈀 {ifname}";
      format-disconnected = "󰤭 offline";
      tooltip-format = "{essid}\n{ipaddr}/{cidr}\n↓ {bandwidthDownBits}  ↑ {bandwidthUpBits}";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "󰝟 muted";
      format-icons.default = [
        "󰕿"
        "󰖀"
        "󰕾"
      ];
      on-click = "pavucontrol";
    };

    cpu = {
      format = " {usage}%";
      interval = 2;
      tooltip = true;
    };
    memory = {
      format = " {percentage}%";
      interval = 5;
    };
    temperature = {
      thermal-zone = 0;
      critical-threshold = 85;
      format = " {temperatureC}°C";
      format-critical = " {temperatureC}°C";
    };
    disk = {
      path = "/";
      format = " {free}";
      interval = 30;
    };
    clock = {
      format = " {:%H:%M}";
      format-alt = " {:%a %d %b %Y}";
      interval = 60;
      tooltip-format = "<tt><small>{calendar}</small></tt>";
    };
    "clock#utc" = {
      format = "UTC {:%H:%M}";
      timezone = "UTC";
      interval = 60;
      tooltip-format = "{:%Y-%m-%d %H:%M:%S %Z}";
    };
    tray = {
      icon-size = 16;
      spacing = 6;
    };

    "custom/notification" = {
      tooltip = true;
      format = "{0} {icon}";
      format-icons = {
        notification = "󱅫";
        none = "󰂜";
        dnd-notification = "󰂠";
        dnd-none = "󰪓";
        inhibited-notification = "󰂛";
        inhibited-none = "󰪑";
        dnd-inhibited-notification = "󰂛";
        dnd-inhibited-none = "󰪑";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };
  }
  // allCustomModules;

  mkLayout =
    {
      name,
      center,
      right,
    }:
    commonBarConfig
    // {
      inherit name;
      modules-left = [ "custom/layout" ] ++ mainLeftModules;
      modules-center = center;
      modules-right = right;
    };

  mainBarConfig = mkLayout {
    name = "main";
    center = [ "hyprland/window" ];
    right = (lib.optional w.mode.enable "custom/mode") ++ [
      "custom/notification"
      "network"
      "pulseaudio"
      "cpu"
      "memory"
      "temperature"
      "disk"
      "clock"
      "tray"
    ];
  };

  opsBarConfig = mkLayout {
    name = "ops";
    center = opsLeftModules;
    right = opsRightModules ++ [
      "custom/notification"
      "tray"
    ];
  };

  infraBarConfig = mkLayout {
    name = "infra";
    center = spineTopModules;
    right =
      spineCenterModules
      ++ spineBottomModules
      ++ [
        "custom/notification"
        "clock"
        "tray"
      ];
  };

  intelBarConfig = mkLayout {
    name = "intel";
    center = if tickerModules == [ ] then [ "hyprland/window" ] else tickerModules;
    right = bannerControlModules ++ [
      "custom/notification"
      "network"
      "clock"
      "tray"
    ];
  };

  launchBarConfig = mkLayout {
    name = "launch";
    center = launchModules;
    right = [
      "custom/notification"
      "network"
      "pulseaudio"
      "clock"
      "tray"
    ];
  };

  waybarJson = pkgs.formats.json { };
  mainConfigFile = waybarJson.generate "waybar-main.json" [ mainBarConfig ];
  opsConfigFile = waybarJson.generate "waybar-ops.json" [ opsBarConfig ];
  infraConfigFile = waybarJson.generate "waybar-infra.json" [ infraBarConfig ];
  intelConfigFile = waybarJson.generate "waybar-intel.json" [ intelBarConfig ];
  launchConfigFile = waybarJson.generate "waybar-launch.json" [ launchBarConfig ];

  waybarRunner = pkgs.writeShellApplication {
    name = "waybar-layout-run";
    runtimeInputs = [
      unstable.waybar
      pkgs.coreutils
    ];
    text = ''
      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/waybar/layout"
      layout=$(cat "$state_file" 2>/dev/null || echo main)

      case "$layout" in
        ops) config="${opsConfigFile}" ;;
        infra) config="${infraConfigFile}" ;;
        intel) config="${intelConfigFile}" ;;
        launch) config="${launchConfigFile}" ;;
        *) config="${mainConfigFile}" ;;
      esac

      style="''${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
      exec waybar -c "$config" -s "$style"
    '';
  };
in
{
  home.packages = [
    layoutCommand
    widgetVisibilityScript
  ];

  systemd.user.services.waybar.Service.ExecStart =
    lib.mkForce "${waybarRunner}/bin/waybar-layout-run";

  programs.waybar = {
    enable = true;
    package = unstable.waybar;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };

    settings.mainBar = mainBarConfig;
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", monospace;
        font-size: 11px;
        font-weight: 500;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: ${cssRgba t.surface t.opacity.bar};
        color: ${cssHex t.fg};
        border: 1px solid ${cssRgba t.accent 0.35};
        border-bottom: 2px solid ${cssRgba t.accent 0.62};
        border-radius: 4px;
      }

      window#waybar.ops {
        background: ${cssRgba t.base 0.62};
        border-color: ${cssRgba t.accentSecondary 0.34};
        border-bottom-color: ${cssRgba t.accentSecondary 0.72};
      }

      window#waybar.infra {
        background: ${cssRgba t.base 0.68};
        border-color: ${cssRgba t.good 0.32};
        border-bottom-color: ${cssRgba t.good 0.68};
      }

      window#waybar.intel {
        background: ${cssRgba t.base 0.64};
        border-color: ${cssRgba t.warn 0.34};
        border-bottom-color: ${cssRgba t.warn 0.68};
      }

      window#waybar.launch {
        background: ${cssRgba t.base 0.58};
        border-color: ${cssRgba t.accent 0.42};
        border-bottom-color: ${cssRgba t.accent 0.76};
      }

      #workspaces { margin: 0 4px; }
      #workspaces button {
        padding: 0 7px;
        margin: 2px 1px;
        color: ${cssHex t.fgDim};
        background: transparent;
        border-radius: 3px;
        border-bottom: 2px solid transparent;
        transition: all 120ms ease;
      }
      #workspaces button:hover {
        color: ${cssHex t.accent};
        background: ${cssRgba t.accent 0.08};
        box-shadow: none;
        text-shadow: none;
      }
      #workspaces button.active {
        color: ${cssHex t.accent};
        background: ${cssRgba t.accent 0.12};
        border-bottom: 2px solid ${cssHex t.accent};
      }
      #workspaces button.urgent {
        color: ${cssHex t.danger};
        background: ${cssRgba t.danger 0.15};
      }

      #window {
        color: ${cssHex t.fg};
        padding: 0 10px;
        font-style: italic;
      }
      #submap {
        color: ${cssHex t.accentSecondary};
        padding: 0 7px;
      }

      #network, #pulseaudio, #cpu, #memory, #disk, #temperature, #clock, #tray,
      #custom-notification,
      #custom-layout,
      #custom-mode,
      #custom-crypto, #custom-stocks, #custom-weather, #custom-hn, #custom-banner-toggle,
      #custom-hud-toggle, #custom-hud-mode, #custom-hud-pi, #custom-hud-news,
      #custom-hud-config, #custom-hud-agents, #custom-hud-services,
      #custom-operator, #custom-matrix, #custom-keyboard, #custom-services,
      #custom-ssh, #custom-fail2ban, #custom-tailscale, #custom-tor,
      #custom-local-ip, #custom-uptime, #custom-identity, #custom-flake,
      #custom-generation, #custom-store, #custom-cloud, #custom-nas,
      #custom-hub, #custom-observability, #custom-ai, #custom-agents,
      #custom-backup, #custom-ports, #custom-containers, #custom-virt {
        padding: 0 7px;
        margin: 2px 1px;
        color: ${cssHex t.fg};
        border-radius: 3px;
        background: ${cssRgba t.base 0.35};
      }

      window#waybar.launch #custom-hud-toggle,
      window#waybar.launch #custom-hud-mode,
      window#waybar.launch #custom-hud-pi,
      window#waybar.launch #custom-hud-news,
      window#waybar.launch #custom-hud-config,
      window#waybar.launch #custom-hud-agents,
      window#waybar.launch #custom-hud-services {
        min-width: 42px;
        min-height: 0;
        padding: 0 9px;
        margin: 2px 2px;
        border: 1px solid ${cssRgba t.accent 0.26};
        border-radius: 4px;
        font-size: 10px;
        font-weight: 800;
      }

      window#waybar.launch #custom-hud-toggle {
        color: ${cssHex t.accentSecondary};
        border-color: ${cssRgba t.accentSecondary 0.40};
      }
      window#waybar.launch #custom-hud-mode {
        color: ${cssHex t.accent};
        border-color: ${cssRgba t.accent 0.45};
      }
      window#waybar.launch #custom-hud-pi {
        color: ${cssHex t.good};
        border-color: ${cssRgba t.good 0.48};
      }
      window#waybar.launch #custom-hud-news {
        color: ${cssHex t.warn};
        border-color: ${cssRgba t.warn 0.38};
      }
      window#waybar.launch #custom-hud-config,
      window#waybar.launch #custom-hud-agents {
        color: ${cssHex t.good};
        border-color: ${cssRgba t.good 0.34};
      }
      window#waybar.launch #custom-hud-services {
        color: ${cssHex t.fg};
        border-color: ${cssRgba t.fg 0.24};
      }

      window#waybar.infra #custom-identity,
      window#waybar.infra #custom-flake,
      window#waybar.infra #custom-generation,
      window#waybar.infra #custom-store,
      window#waybar.infra #custom-cloud,
      window#waybar.infra #custom-nas,
      window#waybar.infra #custom-hub,
      window#waybar.infra #custom-observability,
      window#waybar.infra #custom-ai,
      window#waybar.infra #custom-agents,
      window#waybar.infra #custom-backup,
      window#waybar.infra #custom-ports,
      window#waybar.infra #custom-containers,
      window#waybar.infra #custom-virt,
      window#waybar.infra #clock {
        margin: 2px 1px;
        padding: 0 6px;
        min-height: 0;
        min-width: 0;
      }

      #custom-layout {
        min-width: 62px;
        padding: 0 10px;
        color: ${cssHex t.accent};
        background: ${cssRgba t.accent 0.10};
        border-left: 2px solid ${cssHex t.accent};
        border-right: 1px solid ${cssRgba t.accent 0.34};
        font-weight: 900;
      }
      #custom-layout.ops {
        color: ${cssHex t.accentSecondary};
        background: ${cssRgba t.accentSecondary 0.10};
        border-color: ${cssHex t.accentSecondary};
      }
      #custom-layout.infra {
        color: ${cssHex t.good};
        background: ${cssRgba t.good 0.09};
        border-color: ${cssHex t.good};
      }
      #custom-layout.intel {
        color: ${cssHex t.warn};
        background: ${cssRgba t.warn 0.09};
        border-color: ${cssHex t.warn};
      }
      #custom-layout.launch {
        color: ${cssHex t.accent};
        background: ${cssRgba t.accent 0.14};
        border-color: ${cssHex t.accent};
      }

      #clock {
        color: ${cssHex t.accent};
        font-weight: 700;
      }

      #custom-notification {
        color: ${cssHex t.accentSecondary};
        border-left: 1px solid ${cssRgba t.accentSecondary 0.45};
      }

      #temperature.critical {
        color: ${cssHex t.danger};
        background: ${cssRgba t.danger 0.15};
      }

      /* Ticker states — pulled from `class` in the JSON payload. */
      #custom-crypto.ok    { color: ${cssHex t.good}; }
      #custom-crypto.down  { color: ${cssHex t.danger}; }
      #custom-crypto.error { color: ${cssHex t.fgDim}; }

      #custom-stocks.ok    { color: ${cssHex t.good}; }
      #custom-stocks.down  { color: ${cssHex t.danger}; }
      #custom-stocks.error { color: ${cssHex t.fgDim}; }

      #custom-weather      { color: ${cssHex t.accentSecondary}; }
      #custom-weather.error { color: ${cssHex t.fgDim}; }

      #custom-hn           { color: ${cssHex t.warn}; }
      #custom-hn.error     { color: ${cssHex t.fgDim}; }

      #custom-operator {
        color: ${cssHex t.accentSecondary};
        border-left: 1px solid ${cssRgba t.accentSecondary 0.50};
      }
      #custom-matrix {
        color: ${cssHex t.good};
        font-weight: 700;
      }
      #custom-keyboard {
        color: ${cssHex t.accent};
      }
      #custom-identity {
        color: ${cssHex t.accent};
        font-weight: 800;
        border-left: 1px solid ${cssRgba t.accent 0.55};
      }
      #custom-flake {
        border-left: 1px solid ${cssRgba t.warn 0.38};
      }
      #custom-cloud, #custom-hub, #custom-observability, #custom-ai {
        border-left: 1px solid ${cssRgba t.accentSecondary 0.34};
      }
      #custom-backup, #custom-store {
        border-left: 1px solid ${cssRgba t.good 0.34};
      }
      #custom-local-ip, #custom-uptime {
        color: ${cssHex t.fg};
      }

      #custom-mode.ok, #custom-hud-mode.ok, #custom-hud-toggle.ok {
        color: ${cssHex t.accent};
      }
      #custom-hud-pi.ok {
        color: ${cssHex t.good};
      }
      #custom-hud-news.ok {
        color: ${cssHex t.warn};
      }
      #custom-hud-config.ok, #custom-hud-agents.ok, #custom-hud-services.ok {
        color: ${cssHex t.good};
      }
      #custom-mode.warn, #custom-hud-mode.warn, #custom-hud-toggle.warn,
      #custom-hud-pi.warn, #custom-hud-news.warn, #custom-hud-config.warn,
      #custom-hud-agents.warn, #custom-hud-services.warn {
        color: ${cssHex t.warn};
        background: ${cssRgba t.warn 0.10};
      }
      #custom-mode.down, #custom-mode.error, #custom-hud-mode.down,
      #custom-hud-mode.error, #custom-hud-toggle.down, #custom-hud-toggle.error,
      #custom-hud-pi.down, #custom-hud-pi.error, #custom-hud-news.down,
      #custom-hud-news.error, #custom-hud-config.down, #custom-hud-config.error,
      #custom-hud-agents.down, #custom-hud-agents.error, #custom-hud-services.down,
      #custom-hud-services.error {
        color: ${cssHex t.danger};
        background: ${cssRgba t.danger 0.12};
      }

      #custom-services.ok, #custom-tailscale.ok, #custom-tor.ok,
      #custom-fail2ban.ok, #custom-ssh.ok, #custom-keyboard.ok,
      #custom-local-ip.ok, #custom-uptime.ok, #custom-identity.ok,
      #custom-flake.ok, #custom-generation.ok, #custom-store.ok,
      #custom-cloud.ok, #custom-nas.ok, #custom-hub.ok, #custom-observability.ok,
      #custom-ai.ok, #custom-agents.ok, #custom-backup.ok, #custom-ports.ok,
      #custom-containers.ok, #custom-virt.ok {
        color: ${cssHex t.good};
      }
      #custom-services.warn, #custom-tailscale.warn, #custom-tor.warn,
      #custom-fail2ban.warn, #custom-ssh.warn, #custom-keyboard.warn,
      #custom-local-ip.warn, #custom-uptime.warn, #custom-identity.warn,
      #custom-flake.warn, #custom-generation.warn, #custom-store.warn,
      #custom-cloud.warn, #custom-nas.warn, #custom-hub.warn, #custom-observability.warn,
      #custom-ai.warn, #custom-agents.warn, #custom-backup.warn, #custom-ports.warn,
      #custom-containers.warn, #custom-virt.warn {
        color: ${cssHex t.warn};
        background: ${cssRgba t.warn 0.10};
      }
      #custom-services.down, #custom-tailscale.down, #custom-tor.down,
      #custom-fail2ban.down, #custom-ssh.down, #custom-keyboard.down,
      #custom-local-ip.down, #custom-uptime.down,
      #custom-services.error, #custom-tailscale.error, #custom-tor.error,
      #custom-fail2ban.error, #custom-ssh.error, #custom-keyboard.error,
      #custom-local-ip.error, #custom-uptime.error, #custom-identity.down,
      #custom-flake.down, #custom-generation.down, #custom-store.down,
      #custom-cloud.down, #custom-nas.down, #custom-hub.down, #custom-observability.down,
      #custom-ai.down, #custom-agents.down, #custom-backup.down, #custom-ports.down,
      #custom-containers.down, #custom-virt.down, #custom-identity.error,
      #custom-flake.error, #custom-generation.error, #custom-store.error,
      #custom-cloud.error, #custom-nas.error, #custom-hub.error, #custom-observability.error,
      #custom-ai.error, #custom-agents.error, #custom-backup.error, #custom-ports.error,
      #custom-containers.error, #custom-virt.error {
        color: ${cssHex t.danger};
        background: ${cssRgba t.danger 0.12};
      }

      #custom-banner-toggle.ok {
        color: ${cssHex t.accent};
        border-left: 1px solid ${cssRgba t.accent 0.5};
      }
      #custom-banner-toggle.down {
        color: ${cssHex t.fgDim};
        border-left: 1px solid ${cssRgba t.fgDim 0.45};
      }

      window#waybar.launch #custom-hud-toggle.down {
        color: ${cssHex t.fgDim};
        background: ${cssRgba t.base 0.35};
        border-color: ${cssRgba t.fgDim 0.32};
      }

      #custom-crypto.hidden, #custom-stocks.hidden, #custom-weather.hidden,
      #custom-hn.hidden, #custom-banner-toggle.hidden {
        padding: 0;
        margin: 0;
        background: transparent;
        border: 0;
        min-width: 0;
      }

      window#waybar.launch #custom-hud-mode.hidden,
      window#waybar.launch #custom-hud-pi.hidden,
      window#waybar.launch #custom-hud-news.hidden,
      window#waybar.launch #custom-hud-config.hidden,
      window#waybar.launch #custom-hud-agents.hidden,
      window#waybar.launch #custom-hud-services.hidden {
        padding: 0;
        margin: 0;
        background: transparent;
        border: 0;
        min-width: 0;
        min-height: 0;
      }

      tooltip {
        background: ${cssRgba t.base 0.95};
        border: 1px solid ${cssHex t.accent};
        border-radius: 4px;
      }
      tooltip label {
        color: ${cssHex t.fg};
        padding: 4px 6px;
      }
    '';
  };
}
