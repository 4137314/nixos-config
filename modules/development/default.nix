/*
  development/default.nix — Multi-language development toolchain.

  Scope
  -----
  System-wide compilers, interpreters, language servers, debuggers, and
  container tooling. Per-project versions are expected to be pinned via
  direnv + `use flake` / `use nix`; the packages here provide the fallback
  environment used outside of project shells.

  Language stacks
  ---------------
  C / C++     gcc, clang, cmake, ninja, gnumake, pkg-config, lldb, valgrind.
  Rust        rustup toolchain manager (per-project channels via rust-toolchain).
  Go          go, gopls, delve.
  Node        nodejs 22, pnpm, yarn, typescript, deno, bun.
  Python      python3 + pip + venv, ipython, ruff, black, mypy, poetry, uv.
  Java        JDK 21.
  Shell       shellcheck, shfmt, bash-language-server.
  Web         html/css/json/yaml/toml LSPs.

  Editors / IDE support
  ---------------------
  Language servers here are picked up automatically by Neovim, VS Code, and
  Zed. Formatters (ruff, black, stylua, shfmt) are wired via editor
  format-on-save settings.

  Container / VM
  --------------
  Docker is enabled in modules/workstation/packages.nix. This module adds
  Podman (rootless container runtime) alongside, plus libvirt/qemu for
  full-system VM work (Windows targets during CTFs, isolated malware
  analysis sandboxes).
*/
{ pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # libvirt / QEMU virtualisation for pentest labs and disposable VMs.
  # Rootless container runtime alongside Docker (workstation/packages.nix).
  # ---------------------------------------------------------------------------
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
      };
    };

    podman = {
      enable = true;
      dockerCompat = false;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # ---------------------------------------------------------------------------
  # Language toolchains and LSP servers
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # -- C / C++ / systems ---------------------------------------------------
    gcc
    clang
    clang-tools
    cmake
    ninja
    pkg-config
    lldb
    valgrind
    bear

    # -- Rust ----------------------------------------------------------------
    rustup
    rust-analyzer

    # -- Go ------------------------------------------------------------------
    go
    gopls
    delve
    gotools

    # -- Node / TS / JS ------------------------------------------------------
    nodejs_22
    pnpm
    yarn
    nodePackages.typescript
    nodePackages.typescript-language-server
    deno
    bun

    # -- Python --------------------------------------------------------------
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.ipython
    ruff
    black
    mypy
    poetry
    uv
    pyright

    # -- Java / JVM ----------------------------------------------------------
    jdk21
    maven
    gradle

    # -- Shell / scripting ---------------------------------------------------
    shellcheck
    shfmt
    nodePackages.bash-language-server

    # -- Web / data-format LSPs ----------------------------------------------
    vscode-langservers-extracted
    yaml-language-server
    taplo
    marksman

    # -- Databases -----------------------------------------------------------
    sqlite
    postgresql_16
    redis
    dbeaver-bin
    pgcli

    # -- HTTP / API tooling --------------------------------------------------
    httpie
    curlie
    xh
    grpcurl

    # -- Container ecosystem -------------------------------------------------
    podman-compose
    skopeo
    buildah
    kubernetes-helm
    kubectl
    k9s
    kind
    minikube

    # -- Cloud / IaC ---------------------------------------------------------
    terraform
    ansible
    awscli2

    # -- General dev quality of life ----------------------------------------
    gh
    glab
    hyperfine
    tokei
    watchexec
    just
    delta
    difftastic
    entr
  ];

  programs = {
    virt-manager.enable = true;

    # GnuPG agent — signed commits and pass-based secrets.
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
