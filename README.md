# nixos-hacker-box

NixOS flake configuration for a high-efficiency workstation + local NAS.

**Stack:** NixOS 25.11 · Hyprland · PipeWire · Samba · Syncthing · Docker · Neovim

---

## Repository layout

```
/etc/nixos/
├── flake.nix                   Flake entry point
├── configuration.nix           System configuration (boot, network, users, storage)
├── home.nix                    Home Manager entry point for user "main"
├── hyprland.conf               Native Hyprland config (not managed by Nix)
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

| Alias / command | Description |
|-----------------|-------------|
| `update`        | `nixos-rebuild switch` with this flake |
| `update-dry`    | Dry-run: show what would change |
| `conf`          | Edit `configuration.nix` in Neovim |
| `v`             | Neovim |
| `archive`       | `cd /mnt/archive` |
| `nas-status`    | Status of smbd and syncthing |
| `nas-shares`    | Active Samba connections |
| `red-alert`     | Set all RGB LEDs to solid red |
| `rgb-off`       | Turn off all RGB LEDs |

---

## Development pipeline

```bash
make check        # Full CI check: eval + statix lint + deadnix
make dry          # Dry-activate (preview changes without applying)
make switch       # Apply configuration to the live system
make fmt          # Auto-format all .nix files with nixfmt-rfc-style
make fmt-check    # Check formatting without modifying files
make commit       # Stage all and commit
make update-flake # Bump all flake inputs (nixpkgs, home-manager, …)
```

Run `make check` before every `make switch`.

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

| Job | Steps |
|-----|-------|
| **eval** | `nix flake check --no-build` → evaluate full NixOS config |
| **lint** | `statix` → `deadnix` |

---

## Channels

| Input | Channel |
|-------|---------|
| `nixpkgs` | `nixos-25.11` (stable) |
| `nixpkgs-unstable` | `nixos-unstable` (Neovim only) |
| `home-manager` | `release-25.11` |

Update all inputs: `make update-flake`
