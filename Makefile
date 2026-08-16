FLAKE    := /etc/nixos
HOST     := nixos-hacker-box
TARGET   := .$(shell echo '\#')nixosConfigurations.$(HOST)

# ─────────────────────────────────────────────────────────────────────────────
# Comandi principali
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help switch dry check eval lint dead fmt commit update-flake

## Mostra questo help
help:
	@grep -E '^##' Makefile | sed 's/## //'

## [BUILD] Applica la configurazione al sistema
switch:
	git add -A
	sudo nixos-rebuild switch --flake $(FLAKE)#$(HOST)

## [BUILD] Dry-run: mostra cosa cambierebbe senza applicare
dry:
	git add -A
	sudo nixos-rebuild dry-activate --flake $(FLAKE)#$(HOST)

## [CI] Pipeline completa: eval + lint + dead code
check: git-add eval lint dead
	@echo "✓ Tutti i check passati"

## [CI] Valuta la struttura del flake (no build)
flake-check:
	git add -A
	nix flake check --no-build

## [CI] Valuta la configurazione NixOS (cattura errori di modulo)
eval:
	@echo "→ Valutazione config NixOS..."
	git add -A
	nix eval $(TARGET).config.system.build.toplevel --json > /dev/null
	@echo "✓ eval OK"

## [CI] Lint Nix con statix
lint:
	@echo "→ Lint (statix)..."
	cd $(FLAKE) && nix run nixpkgs#statix -- check --ignore hardware-configuration.nix
	@echo "✓ lint OK"

## [CI] Rileva codice Nix inutilizzato
dead:
	@echo "→ Dead code (deadnix)..."
	nix run nixpkgs#deadnix -- --exclude $(FLAKE)/hardware-configuration.nix $(FLAKE)
	@echo "✓ deadnix OK"

## [FMT] Formatta tutti i file .nix con nixfmt
fmt:
	nix run nixpkgs#nixfmt-rfc-style -- \
		$(FLAKE)/flake.nix \
		$(FLAKE)/configuration.nix \
		$(FLAKE)/home.nix \
		$(shell find $(FLAKE)/modules $(FLAKE)/home -name '*.nix')

## [GIT] Stage di tutti i file (necessario per Nix flake)
git-add:
	git add -A

## [GIT] Commit dopo rebuild riuscito
commit:
	git add -A
	git diff --cached --quiet || git commit -m "nixos: update config"

## [UPDATE] Aggiorna tutti gli input del flake
update-flake:
	nix flake update
	@echo "✓ flake.lock aggiornato — esegui 'make switch' per applicare"

# ─────────────────────────────────────────────────────────────────────────────
# Pipeline consigliata per modifiche alla config:
#   make check && make switch && make commit
# ─────────────────────────────────────────────────────────────────────────────
