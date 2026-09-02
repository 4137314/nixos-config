# nixos-hacker-box

NixOS flake configuration for a high-efficiency workstation + local NAS.

**Stack:** NixOS 25.11 · Hyprland · Zsh/tmux/Kitty · local AI · Docker · Neovim

---

## Repository layout

```
/etc/nixos/
├── flake.nix                   Flake entry point
├── configuration.nix           System configuration (boot, network, users, storage)
├── hardware-configuration.nix  Auto-generated — do not edit
│
└── modules/
    ├── hardware/
    │   ├── audio.nix           PipeWire with low-latency clock profile
    │   └── rgb.nix             OpenRGB + I2C kernel modules
    ├── workstation/
    │   ├── display.nix         Ly TUI display manager
    │   ├── shell.nix           Zsh, aliases, direnv, starship
    │   └── packages.nix        System packages, fonts, Docker
    ├── nas/
    │   ├── samba.nix           SMB share (/mnt/archive) + Avahi mDNS
    │   └── syncthing.nix       P2P file synchronisation
    └── home/
        ├── packages.nix        User packages (dev tools, Nix LSP, …)
        ├── vscode.nix          VS Code + claude-code + nix-ide
        ├── hyprland.nix        Hyprland + hyprexpo plugin
        ├── neovim.nix          Neovim (unstable) + LSP tools
        └── nvim/               Lua config (symlinked to ~/.config/nvim/)
```

---

## Quick reference

| Alias / command     | Description                          |
| ------------------- | ------------------------------------ |
| `update`            | Check, build, then switch this flake |
| `update-dry`        | Dry-run: show what would change      |
| `conf`              | Edit `configuration.nix` in Neovim   |
| `v`                 | Neovim                               |
| `archive`           | `cd /mnt/archive`                    |
| `nas-status`        | Status of smbd and syncthing         |
| `nas-shares`        | Active Samba connections             |
| `red-alert`         | Set all RGB LEDs to solid red        |
| `rgb-off`           | Turn off all RGB LEDs                |
| `aiq`               | Generate a command with local Ollama |
| `f`                 | Correct the previous failed command  |
| `cproj`             | Fuzzy-select and enter a Git project |
| `rgi`               | Ripgrep, preview, then edit a match  |
| `ndiff`             | Compare the newest NixOS generations |
| `, <command>`       | Run any indexed nixpkgs command      |
| `hb-term`           | Open the terminal command palette     |
| `hb-control-center` | Open the central operations TUI       |
| `hb-docs` / `docs`  | Open live documentation and keymaps   |

`Ctrl-R` opens Atuin history, `Ctrl-T` selects files, `Alt-C` selects
directories, `Ctrl-G` opens navi, `Alt-G` selects Git files, and `Alt-E` turns
a natural-language request into an editable shell command through local Ollama.

The `hb` tmux cockpit opens `shell`, `nixos`, `ops`, `pi`, `docs`, and
`control` windows. `pi` is a supervised Pi Coding Agent workspace rooted in
the flake; after an exit it offers restart, continue and session-resume actions
without falling through to a shell. `docs` is the persistent, read-only
knowledge base for the configuration and all terminal/desktop keymaps.
`control` runs the read-only operations centre: Prometheus alerts, persistent
journal views, failed units, timers, NixOS generations, storage, network,
containers, agents, and security state. From any tmux pane, `Ctrl-a I` opens the
same TUI in a popup. Exiting the dedicated `control` window immediately restores
the TUI instead of falling through to a shell. The `pi`, `docs`, and `control`
appliance windows also block tmux's normal pane/window kill keys. Waybar remains
the compact at-a-glance interface.

### Terminal OS / tmux cockpit

`hb-term` is the searchable entry point for development, operations, NixOS,
network, containers, databases, security and AI tools. Rebuilds, flake updates
and garbage collection require an explicit confirmation. The same palette opens
from any pane with `Ctrl-a Space`; the aliases `hub` and `control` open the
palette and the observation dashboard respectively.

| tmux key       | Action                                             |
| -------------- | -------------------------------------------------- |
| `Ctrl-a Space` | Complete terminal/TUI command palette              |
| `Ctrl-a I`     | Control centre popup                               |
| `Ctrl-a i`     | Persistent live documentation window               |
| `Ctrl-a p`     | Persistent Pi Coding Agent workspace               |
| `Ctrl-a C-p`   | Pi popup rooted in the current project             |
| `Ctrl-a o`     | SessionX project/session/window manager            |
| `Ctrl-a m`     | Contextual command menu                            |
| `Ctrl-a F`     | Fuzzy session/window/pane/process manager          |
| `Ctrl-a Tab`   | Extract and copy/insert visible paths, URLs, hashes |
| `Ctrl-a T`     | Vimium-style token hints                           |
| `Ctrl-a u`     | Fuzzy-open a URL from pane history                 |
| `Ctrl-a n`     | Jump to the permanent NixOS workspace              |
| `Ctrl-a ?`     | Cockpit keymap                                     |
| `Ctrl-a y`     | Toggle synchronized input across panes             |
| `Ctrl-a P`     | Toggle persistent logging for the current pane     |
| `Ctrl-a Alt-p` | Capture the visible pane as text                    |

The tmux status line exposes mode, CPU, RAM, failed units, Prometheus alerts and
root filesystem usage. Session state is saved every 15 minutes and restored
after reboot by tmux-resurrect/continuum. Pane logs and retrospective captures
are stored under `~/.local/state/tmux/logs/`.

### Live documentation centre

`hb-docs` unifies the rendered operator manual, configuration architecture,
fuzzy module browser, evaluated NixOS option inspector, man pages, TLDR and navi.
Its keymap views query the running tmux server, Hyprland IPC and Pi JSON files,
with declarative source fallbacks when a live service is unavailable. This keeps
the documentation synchronized with the configuration after future changes.

---

## Development pipeline

```bash
make check        # Eval + lint + dead code + complete system build
make dry          # Dry-activate (preview changes without applying)
make switch       # Apply configuration to the live system
make fmt          # Auto-format all .nix files with nixfmt-rfc-style
make fmt-check    # Check formatting without modifying files
make commit       # Stage all and commit
make update-flake # Bump all flake inputs (nixpkgs, home-manager, …)
```

`make switch` depends on `make check`, so activation cannot accidentally skip
the validation pipeline. Checks use `path:/etc/nixos` and never stage files.

---

## NAS — Samba

The `/mnt/archive` disk is shared over SMB on the local network.

**Initial setup (run once after `make switch`):**

```bash
sudo smbpasswd -a main
```

**Access from other devices:**
| OS | Path |
|----|------|
| Windows | `\\nixos-hacker-box\archive` |
| macOS | `smb://nixos-hacker-box.local/archive` |
| Linux | `smb://nixos-hacker-box.local/archive` |

Avahi (mDNS) makes the host reachable as `nixos-hacker-box.local` without
manual DNS configuration.

## NAS — Syncthing

Web UI: [http://localhost:8384](http://localhost:8384)

Configure folders and peer devices through the UI after the first switch.

---

## Neovim

Neovim is managed declaratively:

- **Binary:** sourced from `nixpkgs-unstable`
- **Config files:** stored in `modules/home/nvim/`, symlinked to `~/.config/nvim/`
- **Plugins:** managed by lazy.nvim (downloads at runtime; `lazy-lock.json` is writable)
- **LSP tools in PATH:** `lua-language-server`, `stylua`, `ripgrep`, `fd`

**First switch with Neovim managed by Nix:**

```bash
mv ~/.config/nvim ~/.config/nvim.bak   # back up existing config
make switch
nvim                                    # then run :Lazy sync
```

---

## Docker

Docker is enabled system-wide. User `main` is in the `docker` group.
Unused images and containers are pruned weekly.

```bash
docker ps
docker compose up -d
```

---

## Per-project Nix environments (direnv)

```bash
echo "use flake" > .envrc
direnv allow
```

The shell activates the project's Nix environment automatically on `cd`.

---

## CI

Every push to `master` triggers two parallel GitHub Actions jobs:

| Job      | Steps                                                     |
| -------- | --------------------------------------------------------- |
| **eval** | `nix flake check --no-build` → evaluate full NixOS config |
| **lint** | `statix` → `deadnix`                                      |

---

## Channels

| Input              | Channel                                |
| ------------------ | -------------------------------------- |
| `nixpkgs`          | `nixos-25.11` (stable)                 |
| `nixpkgs-unstable` | `nixos-unstable` (editors and AI CLIs) |
| `home-manager`     | `release-25.11`                        |

Update all inputs: `make update-flake`
