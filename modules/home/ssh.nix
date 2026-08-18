/*
  home/ssh.nix — OpenSSH client configuration (Home Manager 25.11 layout).

  Defaults
  --------
  ServerAliveInterval / CountMax  Detect dropped connections quickly enough
                                  to keep tmux sessions responsive over VPN.
  HashKnownHosts                  Hash hostnames in ~/.ssh/known_hosts so a
                                  leaked file does not enumerate targets.
  ControlMaster                   Reuse a single TCP connection for repeated
                                  ssh/scp/rsync to the same host.

  In HM 25.11 the top-level `programs.ssh.*` shortcuts have moved under
  `programs.ssh.matchBlocks."*"`. We disable the built-in default block via
  `enableDefaultConfig = false` and provide our own explicit "*" match block
  so we control every field.

  Per-host overrides
  ------------------
  Keep sensitive entries (bug-bounty targets, client jump boxes) in
  ~/.ssh/config.local — sourced by the `Include` directive below. That file
  is intentionally not managed by Nix so credentials never end up in
  the /etc/nixos git history.
*/
_: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks."*" = {
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
      hashKnownHosts = true;
      forwardAgent = false;
      addKeysToAgent = "confirm 1h";
      controlMaster = "auto";
      controlPath = "~/.ssh/control-%r@%h:%p";
      controlPersist = "10m";

      extraOptions = {
        IdentitiesOnly = "yes";
        VerifyHostKeyDNS = "ask";
        StrictHostKeyChecking = "accept-new";
      };
    };

    extraConfig = ''
      # Local per-host overrides — not managed by Nix (intentionally .gitignored).
      Include ~/.ssh/config.local
    '';
  };
}
