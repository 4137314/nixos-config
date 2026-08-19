FLAKE  := /etc/nixos
HOST   := nixos-hacker-box
# The # character starts a Make comment, so we use a shell trick to embed it.
TARGET := .$(shell echo '\#')nixosConfigurations.$(HOST)

NIX_FILES := $(FLAKE)/flake.nix $(FLAKE)/configuration.nix \
             $(shell find $(FLAKE)/modules -name '*.nix' 2>/dev/null)

.PHONY: help switch dry check eval lint dead fmt fmt-check git-add commit update-flake

# ──────────────────────────────────────────────────────────────────────────────
# Default target
# ──────────────────────────────────────────────────────────────────────────────

help:
	@echo "nixos-hacker-box — available targets"
	@echo ""
	@echo "  Build"
	@echo "    switch        Apply the configuration to the live system"
	@echo "    dry           Dry-activate (preview without applying)"
	@echo ""
	@echo "  CI / Quality"
	@echo "    check         Full pipeline: eval + lint + dead-code check"
	@echo "    eval          Evaluate the NixOS config (no build)"
	@echo "    lint          Run statix (Nix anti-pattern linter)"
	@echo "    dead          Run deadnix (unused binding detector)"
	@echo "    fmt-check     Verify nixfmt formatting without modifying files"
	@echo ""
	@echo "  Formatting"
	@echo "    fmt           Auto-format all .nix files with nixfmt-rfc-style"
	@echo ""
	@echo "  Git"
	@echo "    git-add       Stage all changes (required before nix eval)"
	@echo "    commit        Stage all and create a git commit"
	@echo ""
	@echo "  Maintenance"
	@echo "    update-flake  Bump all flake inputs and update flake.lock"

# ──────────────────────────────────────────────────────────────────────────────
# Build
# ──────────────────────────────────────────────────────────────────────────────

switch: git-add
	sudo nixos-rebuild switch --flake $(FLAKE)\#$(HOST)

dry: git-add
	sudo nixos-rebuild dry-activate --flake $(FLAKE)\#$(HOST)

# ──────────────────────────────────────────────────────────────────────────────
# CI / Quality pipeline
# ──────────────────────────────────────────────────────────────────────────────

check: eval lint dead build
	@echo ""
	@echo "✓ All checks passed — safe to run 'make switch'"

eval: git-add
	@echo "→ Evaluating NixOS configuration..."
	@nix eval $(TARGET).config.system.build.toplevel --json > /dev/null
	@echo "✓ eval"

# Actually BUILDS the toplevel derivation (writeShellApplication runs
# shellcheck + bash -n here). `eval` alone does NOT catch these — many
# real bugs hide in shell script bodies embedded in Nix.
build: git-add
	@echo "→ Building toplevel derivation (shellcheck, bash -n, …)..."
	@nix build $(TARGET).config.system.build.toplevel --no-link
	@echo "✓ build"

lint: git-add
	@echo "→ statix (Nix linter)..."
	@cd $(FLAKE) && nix run nixpkgs#statix -- check \
		--ignore hardware-configuration.nix
	@echo "✓ statix"

dead: git-add
	@echo "→ deadnix (unused bindings)..."
	@nix run nixpkgs#deadnix -- \
		--exclude $(FLAKE)/hardware-configuration.nix \
		$(FLAKE)
	@echo "✓ deadnix"

fmt-check:
	@echo "→ Checking nixfmt formatting..."
	@nix run nixpkgs#nixfmt-rfc-style -- --check $(NIX_FILES)
	@echo "✓ fmt-check"

# ──────────────────────────────────────────────────────────────────────────────
# Formatting
# ──────────────────────────────────────────────────────────────────────────────

fmt:
	@echo "→ Formatting .nix files..."
	@nix run nixpkgs#nixfmt-rfc-style -- $(NIX_FILES)
	@echo "✓ fmt"

# ──────────────────────────────────────────────────────────────────────────────
# Git
# ──────────────────────────────────────────────────────────────────────────────

git-add:
	@git add -A

commit: git-add
	@git diff --cached --quiet \
		&& echo "Nothing to commit." \
		|| git commit -m "nixos: update configuration"

# ──────────────────────────────────────────────────────────────────────────────
# Maintenance
# ──────────────────────────────────────────────────────────────────────────────

update-flake:
	@nix flake update
	@echo "✓ flake.lock updated — run 'make switch' to apply"
