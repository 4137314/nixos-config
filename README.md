# HackerBox — NixOS Configuration

Desktop da lavoro iper-efficiente + NAS, gestito interamente con NixOS Flakes.

**Stack:** NixOS 25.11 · Hyprland · PipeWire · Samba · Syncthing · Docker

---

## Struttura

```
/etc/nixos/
├── flake.nix                      Entry point del flake
├── configuration.nix              Sistema: boot, rete, utenti, storage
├── home.nix                       Home Manager: entry point utente "main"
├── hyprland.conf                  Config Hyprland nativa (non gestita da Nix)
├── hardware-configuration.nix     Auto-generato da nixos-generate-config
│
├── modules/
│   ├── hardware/
│   │   ├── audio.nix              PipeWire + profilo low-latency
│   │   └── rgb.nix                OpenRGB + moduli I2C
│   ├── workstation/
│   │   ├── display.nix            Display Manager Ly (TUI, animazione matrix)
│   │   ├── shell.nix              Zsh, alias, direnv, starship
│   │   └── packages.nix           Pacchetti sistema, font, Docker
│   └── nas/
│       ├── samba.nix              Condivisione SMB + Avahi (mDNS)
│       └── syncthing.nix          Sync P2P
│
├── home/
│   ├── packages.nix               Pacchetti utente (Neovim unstable, LSP, ecc.)
│   ├── vscode.nix                 VSCode + estensioni
│   └── hyprland.nix               Hyprland Home Manager wrapper
│
└── .github/
    └── workflows/
        └── check.yml              CI: eval + lint ad ogni push
```

---

## Comandi rapidi

| Alias | Descrizione |
|-------|-------------|
| `update` | `nixos-rebuild switch` con il flake locale |
| `update-dry` | Dry-run: mostra cosa cambierebbe senza applicare |
| `conf` | Apri `configuration.nix` in Neovim (con sudo) |
| `v` | Neovim |
| `ll` / `la` | `ls -l` / `ls -la` |
| `archive` | `cd /mnt/archive` |
| `nas-status` | Stato di smbd e syncthing |
| `nas-shares` | Connessioni Samba attive |
| `red-alert` | LED rosso fisso (OpenRGB) |
| `rgb-off` | LED spenti (OpenRGB) |

---

## NAS

### Samba

Il disco `/mnt/archive` è condiviso sulla rete locale via SMB.

**Setup iniziale** (una tantum):
```bash
sudo smbpasswd -a main
```

**Accesso dalla rete:**
- Windows: `\\nixos-hacker-box\archive`
- macOS: `Finder → Vai → Connetti al server → smb://nixos-hacker-box.local/archive`
- Linux: `smb://nixos-hacker-box.local/archive`

Avahi (mDNS) rende il NAS raggiungibile come `nixos-hacker-box.local` senza DNS.

### Syncthing

Web UI: [http://localhost:8384](http://localhost:8384) — configurare le cartelle al primo avvio.

---

## Docker

```bash
docker ps
docker compose up -d
```

Pruning automatico degli oggetti inutilizzati ogni settimana.

---

## Ambiente Nix per progetto (direnv)

```bash
echo "use flake" > .envrc
direnv allow
```

Direnv attiva automaticamente l'ambiente Nix quando entri nella directory.

---

## CI/CD

Ogni push su `master` esegue:
1. `nix flake check --no-build` — struttura flake
2. `nix eval ...hostName` — valutazione completa config NixOS
3. `statix` — lint best practice Nix
4. `deadnix` — rilevamento codice inutilizzato

---

## Canali

| Input | Canale |
|-------|--------|
| `nixpkgs` | `nixos-25.11` (stabile) |
| `nixpkgs-unstable` | `nixos-unstable` (per Neovim) |
| `home-manager` | `release-25.11` |

Aggiorna i lock: `nix flake update`
