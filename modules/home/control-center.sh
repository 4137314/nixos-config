#!/usr/bin/env bash
# Hacker Box control centre.
# This file is embedded in a writeShellApplication by control-center.nix.

set -uo pipefail

if [ -n "${NO_COLOR:-}" ]; then
  cyan=""
  green=""
  yellow=""
  red=""
  magenta=""
  dim=""
  bold=""
  reset=""
else
  cyan=$'\033[36m'
  green=$'\033[32m'
  yellow=$'\033[33m'
  red=$'\033[31m'
  magenta=$'\033[35m'
  dim=$'\033[2m'
  bold=$'\033[1m'
  reset=$'\033[0m'
fi

export SYSTEMD_COLORS=1
export SYSTEMD_PAGER=cat

self=$(readlink -f "$0")

title() {
  local label=$1
  printf '%s%sHB // CONTROL CENTRE%s  %s%s%s\n' \
    "$bold" "$cyan" "$reset" "$bold" "$label" "$reset"
  printf '%s%s · %s · journal persistente 60d%s\n' \
    "$dim" "$(hostname)" "$(date '+%F %T %Z')" "$reset"
}

section() {
  printf '\n%s%s%s%s\n' "$bold" "$magenta" "$1" "$reset"
}

metric() {
  printf '  %-22s %s\n' "$1" "$2"
}

wait_for_key() {
  printf '\n%sPremi un tasto per tornare al centro di controllo.%s' "$dim" "$reset"
  read -r -s -n 1 _ || true
}

unit_line() {
  local scope=$1
  local unit=$2
  local ctl=(systemctl)
  local load active enabled marker tone

  if [ "$scope" = "user" ]; then
    ctl+=(--user)
  fi

  load=$("${ctl[@]}" show "$unit" --property=LoadState --value 2>/dev/null || true)
  active=$("${ctl[@]}" show "$unit" --property=ActiveState --value 2>/dev/null || true)
  enabled=$("${ctl[@]}" is-enabled "$unit" 2>/dev/null || true)

  if [ "$load" = "not-found" ] || [ -z "$load" ]; then
    marker="·"
    tone=$dim
    active="non installata"
  else
    case "$active" in
      active)
        marker="●"
        tone=$green
        ;;
      failed)
        marker="×"
        tone=$red
        ;;
      activating|deactivating|reloading)
        marker="◐"
        tone=$yellow
        ;;
      *)
        marker="○"
        if [ "$enabled" = "enabled" ]; then
          tone=$yellow
        else
          tone=$dim
        fi
        ;;
    esac
  fi

  printf '  %s%s%s %-31s %-14s %s\n' \
    "$tone" "$marker" "$reset" "$unit" "$active" "$enabled"
}

unit_group() {
  local label=$1
  shift
  section "$label"
  local unit
  for unit in "$@"; do
    unit_line system "$unit"
  done
}

prometheus_query() {
  curl --fail --silent --show-error --max-time 2 \
    --get http://127.0.0.1:9090/api/v1/query \
    --data-urlencode "query=$1"
}

failed_count() {
  local scope=$1
  local ctl=(systemctl)
  if [ "$scope" = "user" ]; then
    ctl+=(--user)
  fi
  "${ctl[@]}" --failed --no-legend --plain 2>/dev/null \
    | awk 'NF { count++ } END { print count + 0 }'
}

alert_count() {
  local payload
  payload=$(prometheus_query 'ALERTS{alertstate=~"firing|pending"}' 2>/dev/null || true)
  if jq -e '.status == "success"' >/dev/null 2>&1 <<<"$payload"; then
    jq -r '.data.result | length' <<<"$payload"
  else
    printf '?\n'
  fi
}

report_overview() {
  local state mode system_failed user_failed errors alerts current booted
  state=$(systemctl is-system-running 2>/dev/null || true)
  mode=$(cat /var/lib/hb-mode/current 2>/dev/null || printf 'dev')
  system_failed=$(failed_count system)
  user_failed=$(failed_count user)
  errors=$(journalctl --since '24 hours ago' --priority=err..alert \
    --quiet --no-pager 2>/dev/null | awk 'NF { count++ } END { print count + 0 }')
  alerts=$(alert_count)
  current=$(readlink /run/current-system 2>/dev/null || printf 'n/d')
  booted=$(readlink /run/booted-system 2>/dev/null || printf 'n/d')

  title "OVERVIEW"
  section "STATO"
  metric "modalità" "${cyan}${mode}${reset}"
  metric "sistema" "${state:-sconosciuto}"
  metric "uptime / load" "$(uptime -p 2>/dev/null || true) · $(cut -d' ' -f1-3 /proc/loadavg)"
  metric "unità fallite" "system ${system_failed} · user ${user_failed}"
  metric "errori journal / 24h" "$errors"
  metric "alert Prometheus" "$alerts"

  section "NIXOS"
  metric "versione" "$(nixos-version 2>/dev/null || printf 'n/d')"
  metric "current" "$current"
  metric "booted" "$booted"
  printf '\n'
  git -C /etc/nixos status --short --branch 2>/dev/null | sed -n '1,12p'

  section "RISORSE"
  free -h | sed -n '1,2p'
  printf '\n'
  df -h --output=source,fstype,size,used,avail,pcent,target \
    / /nix/store /srv/nas 2>/dev/null | awk '!seen[$NF]++'

  section "SERVIZI ESSENZIALI"
  unit_line system sshd.service
  unit_line system tailscaled.service
  unit_line system caddy.service
  unit_line system postgresql.service
  unit_line system prometheus.service
  unit_line system grafana.service
  unit_line system ollama.service
  unit_line system restic-backups-offsite.timer

  section "ULTIMI ERRORI"
  journalctl --since '24 hours ago' --priority=err..alert --quiet --no-pager \
    --output=short-iso 2>/dev/null | tail -n 9
}

report_health() {
  title "SERVICE HEALTH"

  section "UNITÀ FALLITE · SYSTEM"
  if [ "$(failed_count system)" -eq 0 ]; then
    printf '  %snessuna unità fallita%s\n' "$green" "$reset"
  else
    systemctl --failed --no-pager --plain 2>/dev/null
  fi

  section "UNITÀ FALLITE · USER"
  if [ "$(failed_count user)" -eq 0 ]; then
    printf '  %snessuna unità fallita%s\n' "$green" "$reset"
  else
    systemctl --user --failed --no-pager --plain 2>/dev/null
  fi

  unit_group "CORE / ACCESSO" \
    sshd.service fail2ban.service tailscaled.service NetworkManager.service \
    docker.service podman.service libvirtd.service
  unit_group "EDGE / DATI" \
    caddy.service nginx.service postgresql.service redis-nextcloud.service \
    smbd.service syncthing.service forgejo.service jellyfin.service
  unit_group "OSSERVABILITÀ" \
    prometheus.service grafana.service loki.service victoriametrics.service \
    ntfy-sh.service
  unit_group "AI / AUTOMAZIONE" \
    ollama.service open-webui.service home-assistant.service
  unit_group "HUB" \
    miniflux.service navidrome.service vaultwarden.service vikunja.service \
    audiobookshelf.service

  section "DESKTOP · USER"
  unit_line user waybar.service
  unit_line user pipewire.service
  unit_line user wireplumber.service
  unit_line user swaync.service

  local container_units
  container_units=$(systemctl list-unit-files 'podman-*.service' \
    --no-legend --plain 2>/dev/null | awk '{print $1}' | sort -u)
  if [ -n "$container_units" ]; then
    section "CONTAINER SYSTEMD"
    while IFS= read -r unit; do
      [ -n "$unit" ] && unit_line system "$unit"
    done <<<"$container_units"
  fi
}

report_alerts() {
  local payload count probes
  title "ALERTS / PROBES"

  section "PROMETHEUS · FIRING / PENDING"
  payload=$(prometheus_query 'ALERTS{alertstate=~"firing|pending"}' 2>/dev/null || true)
  if ! jq -e '.status == "success"' >/dev/null 2>&1 <<<"$payload"; then
    printf '  %sAPI Prometheus non raggiungibile su 127.0.0.1:9090%s\n' "$yellow" "$reset"
  else
    count=$(jq -r '.data.result | length' <<<"$payload")
    if [ "$count" -eq 0 ]; then
      printf '  %snessun alert attivo%s\n' "$green" "$reset"
    else
      jq -r '.data.result[] |
        [.metric.alertstate, .metric.alertname, (.metric.instance // "-"),
         (.metric.severity // "-")] | @tsv' <<<"$payload" \
        | while IFS=$'\t' read -r alert_state name instance severity; do
            printf '  %s%-8s%s %-28s %-10s %s\n' \
              "$red" "$alert_state" "$reset" "$name" "$severity" "$instance"
          done
    fi
  fi

  section "BLACKBOX HTTP PROBES"
  probes=$(prometheus_query 'probe_success' 2>/dev/null || true)
  if ! jq -e '.status == "success"' >/dev/null 2>&1 <<<"$probes"; then
    printf '  dati probe non disponibili\n'
  else
    jq -r '.data.result[] |
      [(.value[1] // "0"), (.metric.instance // .metric.target // "?")] | @tsv' \
      <<<"$probes" \
      | sort -k2 \
      | while IFS=$'\t' read -r value instance; do
          if [ "$value" = "1" ]; then
            printf '  %s●%s %s\n' "$green" "$reset" "$instance"
          else
            printf '  %s×%s %s\n' "$red" "$reset" "$instance"
          fi
        done
  fi

  section "ULTIME NOTIFICHE LOCALI"
  journalctl -u prometheus.service -u grafana.service -u ntfy-sh.service \
    --since '24 hours ago' --priority=warning..alert --quiet --no-pager \
    --output=short-iso 2>/dev/null | tail -n 16
}

report_log_summary() {
  local range=$1
  local boot_arg=()
  local label

  case "$range" in
    boot)
      label="BOOT CORRENTE · WARNING+"
      boot_arg=(-b)
      ;;
    previous)
      label="BOOT PRECEDENTE · WARNING+"
      boot_arg=(-b -1)
      ;;
    *)
      label="EVENTI IMPORTANTI · 7 GIORNI"
      boot_arg=(--since '7 days ago')
      ;;
  esac

  title "$label"
  section "CONTEGGIO PER UNITÀ"
  journalctl "${boot_arg[@]}" --priority=warning..alert --quiet --no-pager \
    --output=json 2>/dev/null \
    | jq -r '._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // "kernel/other"' \
    | sort | uniq -c | sort -nr | sed -n '1,16p'

  section "EVENTI PIÙ RECENTI"
  journalctl "${boot_arg[@]}" --priority=warning..alert --quiet --no-pager \
    --output=short-iso 2>/dev/null | tail -n 24
}

report_timers() {
  title "TIMERS / SCHEDULES"
  section "SYSTEM"
  systemctl list-timers --all --no-pager --plain 2>/dev/null | sed -n '1,42p'
  section "USER"
  systemctl --user list-timers --all --no-pager --plain 2>/dev/null | sed -n '1,24p'
  section "BACKUP · ULTIMI RISULTATI"
  systemctl show restic-backups-offsite.service restic-verify.service \
    postgresql-backup.service \
    --property=Id --property=Result --property=ExecMainStatus \
    --property=InactiveExitTimestamp 2>/dev/null
}

report_config() {
  local enabled disabled
  enabled=$(rg --count '^[[:space:]]*\./modules/' /etc/nixos/configuration.nix 2>/dev/null || printf '0')
  disabled=$(rg --count '^[[:space:]]*#[[:space:]]*\./modules/' /etc/nixos/configuration.nix 2>/dev/null || printf '0')

  title "NIXOS CONFIG"
  section "GENERAZIONE"
  metric "nixos" "$(nixos-version 2>/dev/null || printf 'n/d')"
  metric "current" "$(readlink /run/current-system 2>/dev/null || printf 'n/d')"
  metric "booted" "$(readlink /run/booted-system 2>/dev/null || printf 'n/d')"
  metric "moduli importati" "$enabled attivi · $disabled commentati"

  section "WORKTREE /etc/nixos"
  git -C /etc/nixos status --short --branch 2>/dev/null

  section "ULTIMI COMMIT"
  git -C /etc/nixos --no-pager log --oneline --decorate -10 2>/dev/null

  section "GENERAZIONI RECENTI"
  nixos-rebuild list-generations 2>/dev/null | sed -n '1,13p'

  section "MODULI ATTIVI"
  rg '^[[:space:]]*\./modules/' /etc/nixos/configuration.nix 2>/dev/null \
    | sed -E 's/^[[:space:]]*//; s/[[:space:]]*#.*$//' \
    | sed -n '1,60p'
}

report_generation() {
  title "GENERATION DIFF"
  section "SORGENTI"
  metric "booted" "$(readlink /run/booted-system 2>/dev/null || printf 'n/d')"
  metric "current" "$(readlink /run/current-system 2>/dev/null || printf 'n/d')"
  printf '\n  Invio apre nvd: differenze dei pacchetti tra booted e current.\n'
}

report_network() {
  title "NETWORK"
  section "INTERFACCE"
  ip -brief address show 2>/dev/null
  section "ROUTE"
  ip route show 2>/dev/null
  section "TAILSCALE"
  printf '  IPv4: %s\n' "$(tailscale ip -4 2>/dev/null || printf 'offline')"
  tailscale status 2>/dev/null | sed -n '1,14p'
  section "SOCKET IN ASCOLTO"
  ss -ltnup 2>/dev/null | sed -n '1,34p'
}

report_storage() {
  title "STORAGE / BACKUP"
  section "FILESYSTEM"
  df -hT -x tmpfs -x devtmpfs 2>/dev/null
  section "BLOCK DEVICES"
  lsblk --output NAME,SIZE,FSTYPE,FSUSE%,MOUNTPOINTS,MODEL 2>/dev/null
  section "MOUNT NAS"
  findmnt --real --target /srv/nas 2>/dev/null || printf '  /srv/nas non montato\n'
  section "BACKUP TIMERS"
  systemctl list-timers --all --no-pager --plain 'restic-*' 'postgresql-*' \
    'btrbk*' 2>/dev/null
  section "ULTIMO BACKUP"
  journalctl -u restic-backups-offsite.service --quiet --no-pager \
    --output=short-iso -n 14 2>/dev/null
  section "SENSORI"
  sensors 2>/dev/null | sed -n '1,28p'
}

report_containers() {
  title "CONTAINERS / VIRTUALISATION"
  section "PODMAN"
  podman ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
    | sed -n '1,28p'
  section "DOCKER"
  docker ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
    | sed -n '1,22p'
  section "LIBVIRT"
  virsh --connect qemu:///system list --all 2>/dev/null
  section "UNITÀ CONTAINER FALLITE"
  systemctl --failed --no-pager --plain 'podman-*' 'docker-*' 2>/dev/null
}

report_agents() {
  title "AGENTS / OBSERVATORY"
  section "HB MODE"
  /run/current-system/sw/bin/hb-mode status 2>/dev/null || printf '  sconosciuto\n'
  section "TIMER AGENTI"
  systemctl list-timers --all --no-pager --plain 'agent-*' 'obs-*' 2>/dev/null \
    | sed -n '1,35p'
  section "UNITÀ FALLITE"
  systemctl --failed --no-pager --plain 'agent-*' 'obs-*' 2>/dev/null
  section "ULTIMI EVENTI OBSERVATORY"
  if [ -r /var/lib/observatory/events.jsonl ]; then
    tail -n 24 /var/lib/observatory/events.jsonl 2>/dev/null \
      | jq -r '[.ts // .time // "", .source // .producer // "",
        .type // .event // ""] | @tsv' 2>/dev/null
  else
    printf '  event store non leggibile o ancora vuoto\n'
  fi
}

report_security() {
  title "SECURITY"
  section "SERVIZI"
  unit_line system sshd.service
  unit_line system fail2ban.service
  unit_line system tailscaled.service
  unit_line system auditd.service
  unit_line system systemd-journal-upload.service
  section "SESSIONI"
  loginctl list-sessions --no-pager --no-legend 2>/dev/null
  section "SSH · WARNING+ · 24H"
  journalctl -u sshd.service --since '24 hours ago' --priority=warning..alert \
    --quiet --no-pager --output=short-iso 2>/dev/null | tail -n 20
  section "KERNEL · WARNING+ · BOOT"
  journalctl --dmesg --boot --priority=warning..alert --quiet --no-pager \
    --output=short-iso 2>/dev/null | tail -n 22
}

report_processes() {
  title "PROCESS PRESSURE"
  section "TOP CPU"
  ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu | sed -n '1,18p'
  section "TOP MEMORY"
  ps -eo pid,user,comm,%mem,%cpu --sort=-%mem | sed -n '1,18p'
}

report_help() {
  title "HELP"
  cat <<'EOF'

NAVIGAZIONE
  ↑/↓ o Ctrl-j/Ctrl-k   scegli una vista
  Invio                 apri la vista o lo strumento
  Ctrl-r                aggiorna il preview selezionato
  Esc                   chiudi il popup; in tmux control il menu si riapre
  q                     torna al menu dalle dashboard live

LOG
  Il journal di sistema è persistente, limitato a 2 GiB e conservato fino a
  60 giorni. Le viste IMPORTANTI, BOOT e BOOT-1 aprono lnav: usa / per cercare,
  i per i filtri e q per tornare qui. UNIT LOGS seleziona sia unità di sistema
  sia unità Home Manager dell'utente.

SICUREZZA OPERATIVA
  Le viste della dashboard sono read-only. TERMINAL OS apre la palette operativa;
  rebuild, update e garbage collection chiedono una conferma esplicita.
EOF
}

report() {
  case "$1" in
    hub) hb-term help ;;
    overview) report_overview ;;
    health|services) report_health ;;
    alerts) report_alerts ;;
    important) report_log_summary important ;;
    boot) report_log_summary boot ;;
    previous) report_log_summary previous ;;
    live) report_log_summary boot ;;
    failed) report_health ;;
    unit) report_health ;;
    timers) report_timers ;;
    config) report_config ;;
    generation) report_generation ;;
    network) report_network ;;
    storage) report_storage ;;
    containers|container-tui) report_containers ;;
    agents) report_agents ;;
    security) report_security ;;
    processes) report_processes ;;
    help|*) report_help ;;
  esac
}

watch_report() {
  local name=$1
  local delay=${2:-5}
  local key

  while true; do
    printf '\033[H\033[2J'
    report "$name"
    printf '\n%sauto-refresh %ss · q per tornare · r per aggiornare ora%s' \
      "$dim" "$delay" "$reset"
    key=""
    if read -r -s -n 1 -t "$delay" key; then
      [ "$key" = "q" ] && break
    fi
  done
}

paged_report() {
  report "$1" | less -R
}

open_log_view() {
  case "$1" in
    important)
      journalctl --since '7 days ago' --priority=warning..alert \
        --output=short-iso --no-pager 2>/dev/null | lnav
      ;;
    boot)
      journalctl --boot --priority=warning..alert --output=short-iso \
        --no-pager 2>/dev/null | lnav
      ;;
    previous)
      journalctl --boot=-1 --priority=warning..alert --output=short-iso \
        --no-pager 2>/dev/null | lnav
      ;;
    live)
      journalctl --follow --output=short-iso 2>/dev/null | lnav
      ;;
  esac
}

unit_preview() {
  local scope=$1
  local unit=$2
  local ctl=(systemctl)
  local journal=(journalctl)

  if [ "$scope" = "user" ]; then
    ctl+=(--user)
    journal+=(--user)
  fi

  title "${scope^^} · $unit"
  "${ctl[@]}" status --no-pager --full "$unit" 2>&1 || true
  section "JOURNAL RECENTE"
  "${journal[@]}" -u "$unit" --no-pager --output=short-iso -n 60 2>/dev/null
}

choose_unit_logs() {
  local choice scope unit
  choice=$(
    {
      systemctl list-units --type=service --all --no-legend --plain 2>/dev/null \
        | awk '{print "system\t" $1}'
      systemctl --user list-units --type=service --all --no-legend --plain 2>/dev/null \
        | awk '{print "user\t" $1}'
    } | sort -u \
      | fzf --height=100% --layout=reverse --border=sharp --ansi \
          --delimiter=$'\t' --with-nth=1,2 \
          --prompt='unit logs › ' \
          --header='Invio: journal 7d in lnav · Esc: indietro' \
          --preview="HB_CC_COLOR=1 $self unit-preview {1} {2}" \
          --preview-window='right,65%,wrap'
  ) || true

  [ -n "$choice" ] || return
  IFS=$'\t' read -r scope unit <<<"$choice"
  if [ "$scope" = "user" ]; then
    journalctl --user -u "$unit" --since '7 days ago' --output=short-iso \
      --no-pager 2>/dev/null | lnav
  else
    journalctl -u "$unit" --since '7 days ago' --output=short-iso \
      --no-pager 2>/dev/null | lnav
  fi
}

choose_failed_unit() {
  local choice scope unit candidates
  candidates=$(
    {
      systemctl --failed --no-legend --plain 2>/dev/null \
        | awk 'NF {print "system\t" $1}'
      systemctl --user --failed --no-legend --plain 2>/dev/null \
        | awk 'NF {print "user\t" $1}'
    } | sort -u
  )

  if [ -z "$candidates" ]; then
    printf '\033[H\033[2J'
    title "FAILED UNIT TRIAGE"
    printf '\n  %sNessuna unità fallita.%s\n' "$green" "$reset"
    wait_for_key
    return
  fi

  choice=$(printf '%s\n' "$candidates" \
    | fzf --height=100% --layout=reverse --border=sharp --ansi \
        --delimiter=$'\t' --with-nth=1,2 --prompt='failed › ' \
        --preview="HB_CC_COLOR=1 $self unit-preview {1} {2}" \
        --preview-window='right,65%,wrap') || true
  [ -n "$choice" ] || return
  IFS=$'\t' read -r scope unit <<<"$choice"

  if [ "$scope" = "user" ]; then
    journalctl --user -u "$unit" --since '7 days ago' --output=short-iso \
      --no-pager 2>/dev/null | lnav
  else
    journalctl -u "$unit" --since '7 days ago' --output=short-iso \
      --no-pager 2>/dev/null | lnav
  fi
}

menu_items() {
  cat <<'EOF'
hub	00  TERMINAL OS       tutte le TUI e le azioni operative confermate
docs	01  DOCUMENTATION     config, keymap tmux/Hyprland/Pi e manuali
overview	02  OVERVIEW          stato, risorse, servizi ed errori recenti
health	03  SERVICE HEALTH    matrice servizi system/user e unità fallite
alerts	04  ALERTS & PROBES   alert Prometheus e probe HTTP
important	05  IMPORTANT LOGS    warning+ persistenti degli ultimi 7 giorni
boot	06  CURRENT BOOT      warning+ del boot corrente
previous	07  PREVIOUS BOOT     warning+ del boot precedente
live	08  LIVE JOURNAL      journal completo in tempo reale
unit	09  UNIT LOGS         scegli una unità e apri 7 giorni in lnav
failed	10  FAILED TRIAGE     scegli una unità fallita e analizzane i log
services	11  SYSTEMCTL TUI     browser interattivo delle unità systemd
timers	12  TIMERS            schedule system/user e risultati backup
config	13  NIXOS CONFIG      worktree, moduli, commit e generazioni
generation	14  GENERATION DIFF   confronto booted/current con nvd
network	15  NETWORK           interfacce, route, Tailscale e socket
storage	16  STORAGE & BACKUP  filesystem, dischi, timer, sensori e restic
containers	17  CONTAINERS       Podman, Docker e libvirt
container-tui	18  LAZYDOCKER       TUI specialistica per i container Docker
agents	19  AGENTS             hb-mode, timer, errori ed eventi Observatory
security	20  SECURITY          accesso, sessioni, SSH e warning kernel
processes	21  PROCESS MONITOR   process pressure e btop
help	22  HELP              navigazione, retention log e confini operativi
EOF
}

run_action() {
  case "$1" in
    hub) hb-term ;;
    docs) hb-docs ;;
    overview) watch_report overview 5 ;;
    health) paged_report health ;;
    alerts) watch_report alerts 10 ;;
    important|boot|previous|live) open_log_view "$1" ;;
    unit) choose_unit_logs ;;
    failed) choose_failed_unit ;;
    services) systemctl-tui ;;
    timers|config) paged_report "$1" ;;
    generation) nvd diff /run/booted-system /run/current-system | less -R ;;
    network|storage|containers|agents|security) watch_report "$1" 5 ;;
    container-tui) lazydocker ;;
    processes) btop ;;
    help) paged_report help ;;
  esac
}

main_menu() {
  local selection key menu_header
  menu_header='Invio: apri · Ctrl-r: refresh preview · Esc: esci · read-only'
  if [ "${HB_CC_PERSISTENT:-0}" = 1 ]; then
    menu_header='Invio: apri · Ctrl-r: refresh preview · Esc: ripristina · pane persistente'
  fi

  while true; do
    selection=$(menu_items \
      | fzf --height=100% --layout=reverse --border=sharp --ansi \
          --delimiter=$'\t' --with-nth=2 \
          --prompt='control › ' \
          --header="$menu_header" \
          --preview="HB_CC_COLOR=1 $self preview {1}" \
          --preview-window='right,68%,wrap' \
          --bind='ctrl-r:refresh-preview') || true

    [ -n "$selection" ] || return 0
    key=$(cut -f1 <<<"$selection")
    run_action "$key"
  done
}

persistent_pane() {
  # The dedicated tmux window is an appliance-like control surface, not a
  # fourth general-purpose shell. Esc and Ctrl-c may close the current fzf
  # process, but the parent loop immediately restores the main dashboard.
  export HB_CC_PERSISTENT=1
  trap ':' INT QUIT
  while true; do
    main_menu || true
    sleep 0.2
  done
}

case "${1:-menu}" in
  preview|report)
    report "${2:-help}"
    ;;
  unit-preview)
    unit_preview "${2:-system}" "${3:-}"
    ;;
  menu)
    main_menu
    ;;
  pane)
    persistent_pane
    ;;
  *)
    printf 'uso: hb-control-center [menu|report <vista>]\n' >&2
    exit 2
    ;;
esac
