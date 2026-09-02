#!/usr/bin/env bash
# Live documentation and keymap browser for nixos-hacker-box.

set -uo pipefail

self=$(readlink -f "$0")
repo=${HB_DOCS_REPO:-/etc/nixos}
cyan=$'\033[36m'
green=$'\033[32m'
yellow=$'\033[33m'
magenta=$'\033[35m'
dim=$'\033[2m'
bold=$'\033[1m'
reset=$'\033[0m'

heading() {
  printf '%s%sHB // DOCS%s  %s\n' "$bold" "$cyan" "$reset" "$1"
  printf '%s%s · live sources · %s%s\n\n' "$dim" "$(hostname)" "$repo" "$reset"
}

menu_items() {
  cat <<'EOF'
overview	00  START      Knowledge map       documentation sources and navigation
readme	01  CONFIG     Operator manual     rendered repository README
architecture	02  CONFIG     Architecture        module tree, conventions and entry points
modules	03  CONFIG     Module browser      fuzzy-read every Nix and script source
options	04  NIXOS      Option inspector    evaluated NixOS option value and documentation
tmux	10  KEYMAP     tmux live keys       loaded server bindings and plugin map
hyprland	11  KEYMAP     Hyprland live keys   compositor bindings with source fallback
pi	12  KEYMAP     Pi coding agent     models, agents, permissions and input keys
shell	13  KEYMAP     Shell / cockpit     aliases, widgets and terminal OS commands
manuals	20  REFERENCE  Man pages           fuzzy system manual browser
tldr	21  REFERENCE  TLDR               practical command examples
cheats	22  REFERENCE  Navi               local operational cheatsheets
history	30  CHANGE     Config history      commits, worktree and recent changes
help	90  HELP       Usage              docs centre navigation
EOF
}

config_files() {
  fd --absolute-path --hidden --type f \
    --extension nix --extension sh --extension lua --extension md \
    --exclude .git . "$repo" 2>/dev/null | sort
}

tmux_keymap() {
  heading "TMUX LIVE KEYMAP"
  printf '%sCOCKPIT%s\n' "$magenta" "$reset"
  hb-term help 2>/dev/null || true

  printf '\n%sDESCRIBED BINDINGS FROM THE RUNNING SERVER%s\n\n' "$magenta" "$reset"
  if tmux list-keys -T prefix -N 2>/dev/null; then
    true
  elif [ -r "$HOME/.config/tmux/tmux.conf" ]; then
    printf '%sNo attached tmux server; showing declarative bindings.%s\n\n' "$yellow" "$reset"
    rg '^[[:space:]]*bind([[:space:]]|$)' "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
  else
    printf 'tmux configuration is not active yet.\n'
  fi

  printf '\n%sPLUGINS%s\n\n' "$magenta" "$reset"
  cat <<'EOF'
  Ctrl-a o              SessionX: sessions, windows, projects and previews
  Ctrl-a F              tmux-fzf: server objects and processes
  Ctrl-a Tab            extrakto: extract path, URL, word or full line
  Ctrl-a T              tmux-thumbs: hint-copy hashes, IPs, paths and URLs
  Ctrl-a u              fuzzy URL opener
  Ctrl-a P              toggle live logging for the current pane
  Ctrl-a Alt-p          capture the visible pane as text
  Ctrl-a Alt-Shift-p    save the complete retained pane history
  Ctrl-a Ctrl-s/r       save / restore tmux-resurrect state
EOF
}

hypr_modifiers() {
  local mask=$1
  local label=""
  ((mask & 64)) && label+="SUPER+"
  ((mask & 4)) && label+="CTRL+"
  ((mask & 8)) && label+="ALT+"
  ((mask & 1)) && label+="SHIFT+"
  label=${label%+}
  printf '%s' "${label:-NONE}"
}

hyprland_keymap() {
  local payload mask key dispatcher argument submap description modifiers
  heading "HYPRLAND LIVE KEYMAP"
  payload=$(hyprctl binds -j 2>/dev/null || true)

  if jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$payload"; then
    printf '%-28s  %-20s  %s\n' "KEY" "DISPATCHER" "ARGUMENT / DESCRIPTION"
    printf '%-28s  %-20s  %s\n' "----------------------------" "--------------------" "------------------------------"
    while IFS=$'\t' read -r mask key dispatcher argument submap description; do
      modifiers=$(hypr_modifiers "${mask:-0}")
      [ -n "$submap" ] && [ "$submap" != "reset" ] && modifiers="[$submap] $modifiers"
      printf '%-28s  %-20s  %s%s\n' \
        "$modifiers+$key" "$dispatcher" "$argument" \
        "${description:+ · $description}"
    done < <(jq -r '.[] | [(.modmask // 0), (.key // ("code:" + ((.keycode // 0) | tostring))), (.dispatcher // ""), (.arg // ""), (.submap // ""), (.description // "")] | @tsv' <<<"$payload")
  else
    printf '%sHyprland IPC unavailable; showing declarative source lines.%s\n\n' "$yellow" "$reset"
    rg --no-heading --line-number \
      '^[[:space:]]*(bind|binde|bindl|bindm|bindd|unbind)[[:space:]]*=' \
      "$repo/modules/home/hyprland/hyprland.conf" \
      "$repo/modules/home/hyprland" --glob '*.nix' 2>/dev/null || true
  fi
}

pi_documentation() {
  heading "PI CODING AGENT"
  printf '%sRUNTIME%s\n\n' "$magenta" "$reset"
  printf '  version   %s\n' "$(pi --version 2>/dev/null | head -n 1 || printf 'not installed')"
  printf '  binary    %s\n' "$(command -v pi 2>/dev/null || printf 'not installed')"
  printf '  workspace tmux hb:pi · SUPER+CTRL+P · Ctrl-a p\n'

  printf '\n%sMODELS%s\n\n' "$magenta" "$reset"
  jq -r '.enabledModels[]? | "  " + .' "$HOME/.pi/agent/settings.json" 2>/dev/null || true

  printf '\n%sKEYMAP%s\n\n' "$magenta" "$reset"
  jq -r 'to_entries[] | "  \(.value | if type == "array" then join(" / ") else . end)\t\(.key)"' \
    "$HOME/.pi/agent/keybindings.json" 2>/dev/null | column -t -s $'\t' || true

  printf '\n%sAGENTS%s\n\n' "$magenta" "$reset"
  for agent in "$HOME"/.pi/agent/agents/*.md; do
    [ -r "$agent" ] || continue
    awk -F': ' '
      /^name:/ { name=$2 }
      /^description:/ { description=$2 }
      /^model:/ { model=$2 }
      /^---$/ && name != "" { printf "  %-18s %-34s %s\n", name, model, description; exit }
    ' "$agent"
  done

  printf '\n%sSAFETY%s\n\n' "$magenta" "$reset"
  printf '  Primary and subagents deny sudo, destructive rm, sops and system activation.\n'
  printf '  Credentials remain runtime-only in ~/.pi/agent/auth.json.\n'
}

shell_documentation() {
  heading "SHELL + TERMINAL OS"
  hb-term help 2>/dev/null || true
  printf '\n%sSHELL WIDGETS%s\n\n' "$magenta" "$reset"
  cat <<'EOF'
  Ctrl-R          Atuin history search
  Ctrl-T          fzf file picker
  Alt-C           fzf directory picker
  Ctrl-G          navi cheatsheet widget
  Alt-G           fzf Git file picker
  Alt-Shift-G     fzf Git branch picker
  Alt-E           natural language to editable command via local Ollama
EOF
}

architecture_report() {
  heading "CONFIG ARCHITECTURE"
  sed -n '1,115p' "$repo/CLAUDE.md" 2>/dev/null
  printf '\n%sMODULE INVENTORY%s\n\n' "$magenta" "$reset"
  printf '  Nix modules  %s\n' "$(fd --type f --extension nix . "$repo/modules" 2>/dev/null | wc -l)"
  printf '  Shell TUIs   %s\n' "$(fd --type f --extension sh . "$repo/modules" 2>/dev/null | wc -l)"
  printf '  Home imports %s\n' "$(rg -c '^[[:space:]]+\./.*\.nix' "$repo/modules/home/default.nix" 2>/dev/null || printf 0)"
}

overview_report() {
  heading "KNOWLEDGE MAP"
  cat <<EOF
  ${green}LIVE SOURCES${reset}
    tmux       running server + ~/.config/tmux/tmux.conf
    Hyprland   compositor IPC + declarative source fallback
    Pi         ~/.pi/agent settings, models, agents and keybindings
    NixOS      evaluated options from $repo

  ${green}STATIC SOURCES${reset}
    operator   README.md
    agents     CLAUDE.md / AGENTS.md
    modules    every .nix, .sh, .lua and .md file in the flake
    history    Git commits and current worktree

  ${yellow}GUARANTEE${reset}
    This centre is read-only. It never changes services, keymaps or secrets.
    Use hb-term for confirmed operational actions and hb-control-center for health.
EOF
}

help_report() {
  heading "USAGE"
  cat <<'EOF'
  Type to filter, arrows or Ctrl-j/Ctrl-k to move, Enter to open.
  Ctrl-r refreshes the selected live preview; Escape returns/closes.

  Dedicated tmux window:
    Ctrl-a i       jump to hb:docs
    Ctrl-a Space   unified terminal command palette
    Ctrl-a I       health and log control centre
    Ctrl-a p       persistent Pi coding agent

  The hb:docs window is persistent: leaving fzf restores this menu and tmux's
  normal pane/window kill keys are guarded just like hb:control.
EOF
}

report() {
  case "${1:-overview}" in
    overview) overview_report ;;
    readme)
      heading "OPERATOR MANUAL"
      sed -n '1,220p' "$repo/README.md" 2>/dev/null
      ;;
    architecture) architecture_report ;;
    modules)
      heading "MODULE INVENTORY"
      config_files | sed -n '1,100p'
      ;;
    options)
      heading "NIXOS OPTION INSPECTOR"
      printf 'Enter an option path, for example:\n\n'
      printf '  services.vikunja.enable\n  programs.hyprland.enable\n  security.audit.enable\n'
      ;;
    tmux) tmux_keymap ;;
    hyprland) hyprland_keymap ;;
    pi) pi_documentation ;;
    shell) shell_documentation ;;
    manuals)
      heading "MAN PAGES"
      man -k . 2>/dev/null | sed -n '1,80p'
      ;;
    tldr)
      heading "TLDR"
      tldr --list 2>/dev/null | sed -n '1,100p'
      ;;
    cheats)
      heading "NAVI CHEATS"
      printf 'Open the interactive navi browser. Local hacker-box recipes are declarative.\n\n'
      sed -n '1,100p' "$HOME/.config/navi/cheats/hacker-box.cheat" 2>/dev/null || true
      ;;
    history)
      heading "CONFIG HISTORY"
      git -C "$repo" status --short --branch 2>/dev/null
      printf '\n'
      git -C "$repo" --no-pager log --decorate --stat -8 2>/dev/null
      ;;
    help) help_report ;;
  esac
}

paged_report() {
  "$self" report "$1" | less -R
}

module_browser() {
  local selected
  selected=$(config_files | fzf --height=100% --layout=reverse --border=sharp \
    --prompt='module docs › ' \
    --header='Invio: read-only pager · Esc: back' \
    --preview='bat --color=always --style=numbers --line-range=:500 {}' \
    --preview-window='right,68%,wrap') || return
  [ -n "$selected" ] && bat --paging=always --style=numbers "$selected"
}

option_browser() {
  local option
  option=$(gum input --prompt='NixOS option › ' \
    --placeholder='services.vikunja.enable') || return
  [ -n "$option" ] || return
  nixos-option --flake "path:$repo#nixos-hacker-box" "$option" 2>&1 | less -R
}

manual_browser() {
  local selected page section
  selected=$(man -k . 2>/dev/null | fzf --height=100% --layout=reverse \
    --border=sharp --prompt='man › ') || return
  [ -n "$selected" ] || return
  page=$(awk '{print $1}' <<<"$selected")
  section=$(sed -E 's/^[^(]*\(([^)]*)\).*/\1/' <<<"$selected")
  man "$section" "$page"
}

tldr_browser() {
  local page
  page=$(tldr --list 2>/dev/null | fzf --height=100% --layout=reverse \
    --border=sharp --prompt='tldr › ') || return
  [ -n "$page" ] && tldr --pager "$page"
}

run_action() {
  case "$1" in
    overview | architecture | tmux | hyprland | pi | shell | history | help) paged_report "$1" ;;
    readme) glow -p "$repo/README.md" ;;
    modules) module_browser ;;
    options) option_browser ;;
    manuals) manual_browser ;;
    tldr) tldr_browser ;;
    cheats) navi ;;
  esac
}

main_menu() {
  local selection key header
  header='Invio: open · Ctrl-r: refresh live preview · Esc: close · read-only'
  if [ "${HB_DOCS_PERSISTENT:-0}" = 1 ]; then
    header='Invio: open · Ctrl-r: refresh · Esc: restore · persistent docs pane'
  fi

  while true; do
    selection=$(menu_items | fzf --height=100% --layout=reverse --border=sharp \
      --delimiter=$'\t' --with-nth=2 --prompt='docs › ' --header="$header" \
      --preview="HB_DOCS_REPO=$repo $self report {1}" \
      --preview-window='right,68%,wrap' \
      --bind='ctrl-r:refresh-preview') || true
    [ -n "$selection" ] || return 0
    key=$(cut -f1 <<<"$selection")
    run_action "$key"
  done
}

persistent_pane() {
  export HB_DOCS_PERSISTENT=1
  trap ':' INT QUIT
  while true; do
    main_menu || true
    sleep 0.2
  done
}

case "${1:-menu}" in
  menu) main_menu ;;
  pane) persistent_pane ;;
  report) report "${2:-overview}" ;;
  *)
    printf 'usage: hb-docs [menu|pane|report <topic>]\n' >&2
    exit 2
    ;;
esac
