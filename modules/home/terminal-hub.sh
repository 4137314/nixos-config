#!/usr/bin/env bash
# Hacker Box terminal command palette.
# Embedded in a writeShellApplication by terminal-hub.nix.

set -uo pipefail

self=$(readlink -f "$0")
cyan=$'\033[36m'
yellow=$'\033[33m'
magenta=$'\033[35m'
dim=$'\033[2m'
bold=$'\033[1m'
reset=$'\033[0m'

heading() {
  printf '%s%sHB // TERMINAL OS%s  %s\n' "$bold" "$cyan" "$reset" "$1"
  printf '%s%s · %s · %s%s\n\n' \
    "$dim" "$(hostname)" "$(date '+%F %T %Z')" "$PWD" "$reset"
}

menu_items() {
  cat <<'EOF'
control	00  CORE      Control centre       health, alerts, logs and configuration
docs	01  CORE      Documentation        config, keymaps, manuals and live references
window-control	02  TMUX      Window · control     jump to the permanent dashboard
window-shell	03  TMUX      Window · shell       jump to the primary shell
window-nixos	04  TMUX      Window · nixos       jump to the flake workspace
window-ops	05  TMUX      Window · ops         jump to the operator shell
window-docs	06  TMUX      Window · docs        jump to the permanent knowledge base
window-pi	07  TMUX      Window · pi          jump to the persistent coding agent
tmux-tree	08  TMUX      Session tree         sessions, windows and panes
tmux-new	09  TMUX      New dev window       create a window in the current path
files	10  DEV       Files · yazi         file manager with previews
git	11  DEV       Git · lazygit        repository control surface
editor	12  DEV       Editor · Neovim      edit the current project
search	13  DEV       Refactor · serpl      interactive search and replace
tasks	14  DEV       Tasks · mprocs       concurrent project processes
http	15  DEV       HTTP · posting       terminal API client
database	16  DEV       DB · rainfrog        SQL explorer and query console
database-lazy	17  DEV       DB · lazysql         multi-database administration
processes	20  SYSTEM    Processes · btop     CPU, memory, disks and processes
services	21  SYSTEM    Services · systemd   inspect and operate systemd units
logs	22  SYSTEM    Logs · lnav          live persistent journal
kernel	23  SYSTEM    Kernel · kmon        modules, messages and kernel data
disk	24  SYSTEM    Disk · gdu           interactive home usage explorer
containers	30  RUNTIME   Docker · lazydocker container lifecycle and logs
podman	31  RUNTIME   Podman · podman-tui  rootful system containers
kubernetes	32  RUNTIME   Kubernetes · k9s    cluster workloads and logs
net-manager	40  NETWORK   NetworkManager      connections and Wi-Fi via nmtui
net-path	41  NETWORK   Path · trippy        hop latency to a selected target
net-flow	42  NETWORK   Flows · bandwhich    per-process bandwidth (sudo)
packets	43  NETWORK   Packets · termshark   packet capture and analysis (sudo)
ssh	44  NETWORK   SSH host picker      connect using ~/.ssh/config
mode	50  HOST      HB mode             switch study/dev/hack/work/server mode
config-check	51  NIXOS     Validate config      eval, lint, dead code and build
config-dry	52  NIXOS     Dry activate         preview activation (sudo)
config-switch	53  NIXOS     Switch generation    validate and activate (sudo)
flake-update	54  NIXOS     Update flake         update every locked input
generation-diff	55  NIXOS     Generation diff     compare booted and current systems
store	56  NIXOS     Store explorer       inspect Nix closure disk usage
options	57  NIXOS     Option explorer      browse the evaluated option tree
garbage	58  NIXOS     Garbage collect      delete store paths older than 30d
project	60  WORKFLOW  Project picker       open a Git project in a tmux window
agent-pi	61  AI        Pi                  local-first coding agent
agent-claude	62  AI        Claude Code         cloud coding agent
agent-codex	63  AI        Codex               coding agent
agent-chat	64  AI        AIChat              Ollama terminal chat
metasploit	70  SECURITY  Metasploit          exploitation console
cheats	80  HELP      Navi cheats          searchable operational recipes
help	81  HELP      Keymap              tmux cockpit and plugin reference
shell	90  ESCAPE    Login shell         full zsh in the current popup
EOF
}

describe() {
  local key=$1
  heading "PREVIEW"

  case "$key" in
    control)
      hb-control-center report overview 2>/dev/null | sed -n '1,48p'
      ;;
    docs)
      hb-docs report overview 2>/dev/null | sed -n '1,48p'
      ;;
    window-*|tmux-tree|tmux-new)
      printf '%sTMUX COCKPIT%s\n\n' "$magenta" "$reset"
      tmux list-windows -t hb -F \
        '  #{window_index}:#{window_name}  #{pane_current_command}  #{pane_current_path}' \
        2>/dev/null || printf '  tmux session hb non disponibile\n'
      ;;
    git|editor|search|tasks|project)
      printf '%sPROJECT%s\n\n' "$magenta" "$reset"
      git status --short --branch 2>/dev/null || printf '  %s non è un repository Git\n' "$PWD"
      printf '\n'
      git --no-pager log --oneline -8 2>/dev/null || true
      ;;
    services)
      printf '%sFAILED UNITS%s\n\n' "$magenta" "$reset"
      systemctl --failed --no-pager --plain 2>/dev/null || true
      printf '\n%sUSER FAILED%s\n\n' "$magenta" "$reset"
      systemctl --user --failed --no-pager --plain 2>/dev/null || true
      ;;
    logs)
      printf '%sJOURNAL · WARNING+%s\n\n' "$magenta" "$reset"
      journalctl --boot --priority=warning..alert --quiet --no-pager \
        --output=short-iso 2>/dev/null | tail -n 30
      ;;
    processes|kernel|disk)
      printf '%sHOST PRESSURE%s\n\n' "$magenta" "$reset"
      uptime
      free -h | sed -n '1,2p'
      printf '\n'
      df -h --output=source,size,used,avail,pcent,target / /nix/store 2>/dev/null
      ;;
    containers|podman|kubernetes)
      printf '%sCONTAINERS%s\n\n' "$magenta" "$reset"
      podman ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | sed -n '1,18p'
      printf '\n'
      docker ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | sed -n '1,14p'
      ;;
    net-*)
      printf '%sNETWORK%s\n\n' "$magenta" "$reset"
      ip -brief address show 2>/dev/null
      printf '\n'
      ip route show 2>/dev/null
      printf '\nPrivileged capture/flow tools ask for sudo only after selection.\n'
      ;;
    config-*|flake-update|generation-diff|store|options|garbage)
      printf '%sNIXOS%s\n\n' "$magenta" "$reset"
      printf 'current  %s\n' "$(readlink /run/current-system 2>/dev/null || printf 'n/d')"
      printf 'booted   %s\n\n' "$(readlink /run/booted-system 2>/dev/null || printf 'n/d')"
      git -C /etc/nixos status --short --branch 2>/dev/null | sed -n '1,24p'
      printf '\n%sActions that mutate the host require an explicit confirmation.%s\n' \
        "$yellow" "$reset"
      ;;
    mode)
      printf '%sHOST MODES%s\n\n' "$magenta" "$reset"
      /run/current-system/sw/bin/hb-mode status 2>/dev/null || true
      printf '\n'
      /run/current-system/sw/bin/hb-mode list 2>/dev/null || true
      ;;
    ssh)
      printf '%sSSH TARGETS%s\n\n' "$magenta" "$reset"
      ssh_hosts | sed -n '1,30p'
      ;;
    database|database-lazy)
      printf '%sDATABASE%s\n\n' "$magenta" "$reset"
      printf 'rainfrog  fast SQL query/explorer TUI\n'
      printf 'lazysql   multi-engine database administration TUI\n\n'
      printf 'Credentials are read from each tool environment/config, never from Nix.\n'
      ;;
    agent-*)
      printf '%sAI WORKBENCH%s\n\n' "$magenta" "$reset"
      printf 'Pi      local-first multi-model coding harness\n'
      printf 'Claude  Claude Code in the current project\n'
      printf 'Codex   Codex in the current project\n'
      printf 'AIChat  local Ollama conversation and command assistance\n'
      ;;
    help)
      help_text
      ;;
    *)
      printf '%s%s%s\n\n' "$magenta" "$(menu_items | awk -F '\t' -v key="$key" '$1 == key {print $2}')" "$reset"
      printf 'Launches the selected specialist terminal interface in %s.\n' "$PWD"
      ;;
  esac
}

help_text() {
  cat <<'EOF'
TMUX CORE
  Ctrl-a Space   terminal command palette
  Ctrl-a I       control centre popup
  Ctrl-a i       jump to the permanent documentation TUI
  Ctrl-a p       jump to the persistent Pi coding agent
  Ctrl-a o       SessionX project/session manager with previews
  Ctrl-a m       contextual tmux command menu
  Ctrl-a F       tmux-fzf sessions/windows/panes/processes
  Ctrl-a Tab     extract/copy/insert visible text with extrakto
  Ctrl-a T       hint-copy paths, hashes, IPs and URLs with tmux-thumbs
  Ctrl-a u       fuzzy-select and open a URL from the pane
  Ctrl-a n       jump to the permanent NixOS workspace
  Ctrl-a ?       this keymap

OPERATOR POPUPS
  Ctrl-a g/e/b/S/D   lazygit / yazi / btop / systemd / Docker
  Ctrl-a C/O/a/A     Claude / Codex / AIChat / Posting
  Ctrl-a C-p/t/h     Pi popup / mprocs / Helix

PANES / WINDOWS
  Ctrl-a | / -       split right / down in the current directory
  Ctrl-a H/J/K/L     resize pane
  Ctrl-h/j/k/l       seamless Neovim/tmux navigation
  Ctrl-a y           toggle synchronized input across panes
  Alt-1..9           jump directly to a window

STATE
  Ctrl-a P           toggle persistent logging for the current pane
  Ctrl-a Alt-p       textual capture of the visible pane
  Ctrl-a x / &       kill pane/window (blocked in control/docs/Pi)
  Ctrl-a Ctrl-s       save tmux-resurrect state
  Ctrl-a Ctrl-r       restore tmux-resurrect state
  Ctrl-a r            reload tmux configuration
EOF
}

require_tmux() {
  if [ -z "${TMUX:-}" ]; then
    printf 'Questa azione richiede una sessione tmux.\n' >&2
    sleep 1
    return 1
  fi
}

select_window() {
  require_tmux || return
  tmux select-window -t "hb:$1"
}

confirm_make() {
  local target=$1
  local description=$2
  printf '\033[H\033[2J'
  heading "NIXOS ACTION"
  printf '%s\n\n' "$description"
  gum confirm --affirmative='esegui' --negative='annulla' \
    "Confermi: make $target?" || return 0
  cd /etc/nixos || return 1
  exec make "$target"
}

confirm_garbage() {
  printf '\033[H\033[2J'
  heading "NIX STORE GC"
  printf 'Elimina le generazioni non referenziate più vecchie di 30 giorni.\n\n'
  gum confirm --affirmative='elimina' --negative='annulla' \
    'Confermi la garbage collection?' || return 0
  exec sudo nix-collect-garbage --delete-older-than 30d
}

pick_mode() {
  local choice mode
  choice=$(/run/current-system/sw/bin/hb-mode list 2>/dev/null \
    | sed 's/^  //' \
    | fzf --height=100% --layout=reverse --border=sharp \
        --prompt='hb-mode › ') || return
  mode=$(awk '{print $1}' <<<"$choice")
  [ -n "$mode" ] && /run/current-system/sw/bin/hb-mode "$mode"
}

pick_interface() {
  ip -o link show 2>/dev/null \
    | awk -F': ' '$2 != "lo" {sub(/@.*/, "", $2); print $2}' \
    | sort -u \
    | fzf --height=100% --layout=reverse --border=sharp --prompt='interface › '
}

ssh_hosts() {
  rg --no-filename '^[[:space:]]*Host[[:space:]]+' \
    "$HOME/.ssh/config" "$HOME/.ssh/config.d" 2>/dev/null \
    | sed -E 's/^[[:space:]]*Host[[:space:]]+//' \
    | tr ' ' '\n' \
    | rg -v '[*?!]' \
    | sort -u
}

pick_ssh() {
  local host
  host=$(ssh_hosts | fzf --height=100% --layout=reverse --border=sharp \
    --prompt='ssh › ') || return
  [ -n "$host" ] && exec ssh "$host"
}

pick_project() {
  local project
  project=$(fd --hidden --type d '^\.git$' --max-depth 7 "$HOME" /etc/nixos \
    2>/dev/null \
    | sed -E 's#/.git/?$##' \
    | sort -u \
    | fzf --height=100% --layout=reverse --border=sharp \
        --prompt='project › ' \
        --preview='git -C {} status --short --branch 2>/dev/null; git -C {} --no-pager log --oneline -8 2>/dev/null') || return
  [ -n "$project" ] || return

  if [ -n "${TMUX:-}" ]; then
    tmux new-window -c "$project" -n "$(basename "$project" | cut -c1-18)"
  else
    cd "$project" || return 1
    exec zsh -l
  fi
}

run_action() {
  local key=$1
  local target iface
  case "$key" in
    control) exec hb-control-center ;;
    docs) exec hb-docs ;;
    window-control) select_window control ;;
    window-shell) select_window shell ;;
    window-nixos) select_window nixos ;;
    window-ops) select_window ops ;;
    window-docs) select_window docs ;;
    window-pi) select_window pi ;;
    tmux-tree) require_tmux && tmux choose-tree -Zw ;;
    tmux-new) require_tmux && tmux new-window -c "$PWD" -n dev ;;
    files) exec yazi ;;
    git) exec lazygit ;;
    editor) exec nvim . ;;
    search) exec serpl ;;
    tasks) exec mprocs ;;
    http) exec posting ;;
    database) exec rainfrog ;;
    database-lazy) exec lazysql ;;
    processes) exec btop ;;
    services) exec systemctl-tui ;;
    logs) exec bash -c 'journalctl --follow --output=short-iso | lnav' ;;
    kernel) exec kmon ;;
    disk) exec gdu "$HOME" ;;
    containers) exec lazydocker ;;
    podman) exec sudo podman-tui ;;
    kubernetes) exec k9s ;;
    net-manager) exec nmtui ;;
    net-path)
      target=$(gum input --prompt='target › ' --value='1.1.1.1')
      [ -n "$target" ] && exec trip "$target"
      ;;
    net-flow)
      iface=$(pick_interface) || return
      [ -n "$iface" ] && exec sudo bandwhich --interface "$iface"
      ;;
    packets)
      iface=$(pick_interface) || return
      [ -n "$iface" ] && exec sudo termshark -i "$iface"
      ;;
    ssh) pick_ssh ;;
    mode) pick_mode ;;
    config-check) confirm_make check 'Valida evaluation, lint, dead code e build completo.' ;;
    config-dry) confirm_make dry 'Esegue una dry-activation senza cambiare il sistema attivo.' ;;
    config-switch) confirm_make switch 'Valida e attiva una nuova generazione NixOS.' ;;
    flake-update) confirm_make update-flake 'Aggiorna tutti gli input bloccati in flake.lock.' ;;
    generation-diff) exec nvd diff /run/booted-system /run/current-system ;;
    store) exec nix-du ;;
    options) exec nix-inspect ;;
    garbage) confirm_garbage ;;
    project) pick_project ;;
    agent-pi) exec pi --agent hacker-box --name hacker-box ;;
    agent-claude) exec claude ;;
    agent-codex) exec codex ;;
    agent-chat) exec aichat ;;
    metasploit) exec msfconsole ;;
    cheats) exec navi ;;
    help) help_text | less -R ;;
    shell) exec zsh -l ;;
  esac
}

main_menu() {
  local selection key
  selection=$(menu_items \
    | fzf --height=100% --layout=reverse --border=sharp --ansi \
        --delimiter=$'\t' --with-nth=2 \
        --prompt='terminal os › ' \
        --header='Invio: launch · type: filter · Esc: close · mutating actions confirm' \
        --preview="HB_TERM_PREVIEW=1 $self preview {1}" \
        --preview-window='right,62%,wrap' \
        --bind='ctrl-r:refresh-preview') || return 0
  key=$(cut -f1 <<<"$selection")
  [ -n "$key" ] && run_action "$key"
}

case "${1:-menu}" in
  menu) main_menu ;;
  preview) describe "${2:-help}" ;;
  help) help_text ;;
  *)
    printf 'uso: hb-term [menu|help|preview <key>]\n' >&2
    exit 2
    ;;
esac
