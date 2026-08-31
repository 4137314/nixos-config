/*
  system/modes.nix — Runtime "personas" for the workstation.

  Rationale
  ---------
  A workstation with this many services (desktop + NAS + AI + hub +
  pentest) does not want one monolithic on/off switch. Instead we
  expose a handful of *modes* that flip the running configuration
  in seconds without a rebuild:

    study                Quiet research/reading mode. Notifications off,
                         search/research helpers kept available.
    dev      (default)   Everything on. General coding / hacking.
    hack                 Pentest posture: noisy alerts muted, recon/search
                         helpers kept available.
    work                 Practical work mode. Notifications on, noisy
                         lab builders trimmed back.
    personal             Personal cloud / media / home mode. Notifications
                         on, heavier lab builders stopped.
    focus                Notifications silenced, LLM agents paused,
                         browsers stay open — for deep-work sessions.
    night                Warm screen colour, notifications silenced
                         except critical alerts.
    server                AI heavyweights and desktop niceties off,
                         core infra (ssh, tailscale, backups, ollama,
                         nextcloud, forgejo, monitoring) still up.
    legacy aliases       focus/night/server remain available for existing
                         muscle memory and scripts.

  Implementation
  --------------
  A single shell utility `hb-mode` (installed system-wide) toggles
  a whitelisted set of systemd units and emits a desktop notification.
  Group `hb-modes` grants polkit permission to control those units
  without a password prompt.

  Current mode is persisted in `/var/lib/hb-mode/current` (world-
  readable so `waybar` / prompts can display it) and reset to `dev`
  on every boot via a oneshot service.

  Adding a mode
  -------------
  1. Extend `modes` below with the new mode name and its `enter` /
     `leave` action lists (`start`, `stop`, `notify`).
  2. If new systemd units need to be togglable, add them to
     `manageableUnits` so the polkit rule allows them.
  3. Nothing else — the CLI reads the list at runtime from the JSON
     spec generated below.
*/
{ pkgs, ... }:
let
  # --------------------------------------------------------------------------
  # Units the mode CLI is allowed to start / stop without a password.
  # Keep this list narrow — the polkit rule below whitelists it verbatim.
  # Only include units that actually exist on this host; missing units
  # produce noisy stderr at every boot even with `|| true` in the CLI.
  # --------------------------------------------------------------------------
  manageableUnits = [
    # AI heavyweights (large RAM; stopped in `server`).
    "podman-perplexica.service"
    "podman-flowise.service"
    "podman-searxng.service"

    # Notification sink — silenced in focus / night / hack modes.
    "ntfy-sh.service"
  ];

  # --------------------------------------------------------------------------
  # Mode table. Each entry lists `stop` and `start` unit sets plus a
  # short user-facing message.
  # --------------------------------------------------------------------------
  modes = {
    study = {
      message = "Study mode — quiet desk, research helpers ready.";
      stop = [ "ntfy-sh.service" ];
      start = [ "podman-searxng.service" ];
    };

    dev = {
      message = "Dev mode — full workstation online.";
      stop = [ ];
      start = manageableUnits;
    };

    hack = {
      message = "Hack mode — alerts muted; bring up VPN before scanning.";
      stop = [ "ntfy-sh.service" ];
      start = [
        "podman-searxng.service"
        "podman-flowise.service"
      ];
    };

    work = {
      message = "Work mode — notifications on, lab builders quiet.";
      stop = [
        "podman-perplexica.service"
        "podman-flowise.service"
      ];
      start = [
        "ntfy-sh.service"
        "podman-searxng.service"
      ];
    };

    personal = {
      message = "Personal mode — home services front and centre.";
      stop = [
        "podman-perplexica.service"
        "podman-flowise.service"
      ];
      start = [ "ntfy-sh.service" ];
    };

    focus = {
      message = "Focus mode — notifications off.";
      stop = [ "ntfy-sh.service" ];
      start = [ ];
    };

    night = {
      message = "Night mode — warm colours, notifications off.";
      stop = [ "ntfy-sh.service" ];
      start = [ ];
    };

    server = {
      message = "Server mode — desktop heavyweights stopped.";
      stop = [
        "podman-perplexica.service"
        "podman-flowise.service"
        "podman-searxng.service"
      ];
      start = [ ];
    };

    # Kept as an explicit alias for older scripts; prefer `hack`.
    recon = {
      message = "Recon mode — alerts muted; bring up VPN before scanning.";
      stop = [ "ntfy-sh.service" ];
      start = [
        "podman-searxng.service"
        "podman-flowise.service"
      ];
    };
  };

  # --------------------------------------------------------------------------
  # Serialise the mode table to JSON so the shell script does not need
  # any templating logic beyond `jq`.
  # --------------------------------------------------------------------------
  modesJson = pkgs.writeText "hb-modes.json" (builtins.toJSON modes);

  # --------------------------------------------------------------------------
  # The `hb-mode` CLI.
  # --------------------------------------------------------------------------
  hb-mode = pkgs.writeShellApplication {
    name = "hb-mode";
    runtimeInputs = with pkgs; [
      systemd
      jq
      coreutils
      libnotify
      # `hyprctl` is provided by the running Hyprland session's PATH;
      # not included here so this module does not pull the whole
      # compositor into /run/current-system.
    ];
    text = ''
      set -euo pipefail

      SPEC=${modesJson}
      STATE=/var/lib/hb-mode/current

      usage() {
        cat <<'EOF'
      hb-mode — switch workstation persona
      Usage:
        hb-mode <mode>     Switch to <mode> (study|dev|hack|work|personal)
        hb-mode status     Print the currently active mode
        hb-mode list       Print available modes with their descriptions
      EOF
        exit "$1"
      }

      notify() {
        local msg="$1"
        # `notify-send` may not have a bus if invoked from a TTY without
        # DISPLAY / DBUS — that is fine, just print instead.
        if [[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
          notify-send -a hb-mode "hb-mode" "$msg" || true
        fi
        echo "$msg"
      }

      apply_night_shader() {
        # Best-effort: only meaningful inside a running Hyprland session.
        command -v hyprctl >/dev/null 2>&1 || return 0
        hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1 || true
      }

      case "''${1:-}" in
        ""|-h|--help) usage 0 ;;
        status) cat "$STATE" 2>/dev/null || echo unknown; exit 0 ;;
        list)
          jq -r 'to_entries[] | "  \(.key)\t\(.value.message)"' "$SPEC"
          exit 0
          ;;
      esac

      mode="$1"
      if ! jq -e --arg m "$mode" 'has($m)' "$SPEC" >/dev/null; then
        echo "hb-mode: unknown mode '$mode'" >&2
        usage 2
      fi

      # Stop units, then start units.
      mapfile -t to_stop  < <(jq -r --arg m "$mode" '.[$m].stop[]'  "$SPEC")
      mapfile -t to_start < <(jq -r --arg m "$mode" '.[$m].start[]' "$SPEC")

      # `--no-block` avoids blocking the terminal on slow container starts.
      for unit in "''${to_stop[@]}";  do systemctl stop  --no-block "$unit" || true; done
      for unit in "''${to_start[@]}"; do systemctl start --no-block "$unit" || true; done

      if [[ "$mode" == "night" ]]; then apply_night_shader; fi

      # Persist the new mode. Requires membership in `hb-modes` (tmpfiles
      # rule gives that group write access).
      echo "$mode" > "$STATE"

      msg=$(jq -r --arg m "$mode" '.[$m].message' "$SPEC")
      notify "$msg"
    '';
  };
in
{
  # --------------------------------------------------------------------------
  # Group + state file.
  # --------------------------------------------------------------------------
  users.groups.hb-modes = { };

  environment.systemPackages = [ hb-mode ];

  systemd.tmpfiles.rules = [
    "d /var/lib/hb-mode                 0755 root hb-modes -"
    "f /var/lib/hb-mode/current         0664 root hb-modes - dev"
  ];

  # --------------------------------------------------------------------------
  # Boot always starts in `dev` mode. Any unit stopped by a previous
  # session's mode-switch is brought back up here.
  # --------------------------------------------------------------------------
  # Attach to `default.target` (graphical on desktop) instead of
  # `multi-user.target` so a slow / failing container in the mode's
  # `start` list can never block the boot chain multi-user → graphical.
  # Ordered after `network-online.target` so we do not fire before
  # containers themselves are legitimately able to pull images.
  systemd.services.hb-mode-reset = {
    description = "Reset workstation persona to dev after boot";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hb-mode}/bin/hb-mode dev";
    };
  };

  # --------------------------------------------------------------------------
  # Polkit — grant the `hb-modes` group start/stop on whitelisted units
  # without a password prompt.
  # --------------------------------------------------------------------------
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id !== "org.freedesktop.systemd1.manage-units") return;
      if (!subject.isInGroup("hb-modes")) return;
      var unit = action.lookup("unit") || "";
      var allowed = ${builtins.toJSON manageableUnits};
      if (allowed.indexOf(unit) >= 0) return polkit.Result.YES;
    });
  '';

}
