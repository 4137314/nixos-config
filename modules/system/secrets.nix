/*
  system/secrets.nix — sops-nix secret management.

  Bootstrap (one-time, per operator)
  ----------------------------------
    1. nix shell nixpkgs#age nixpkgs#sops nixpkgs#ssh-to-age
    2. age-keygen -o ~/.config/sops/age/keys.txt
       age-keygen -y ~/.config/sops/age/keys.txt   # note the public key
    3. sudo mkdir -p /var/lib/sops-nix
       sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key \
         | sudo tee /var/lib/sops-nix/host.age >/dev/null
       sudo ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub  # note host pubkey
    4. Paste both public keys into `.sops.yaml` at the repo root.
    5. cd /etc/nixos && sops secrets/secrets.yaml
       (populate with the block shown under "Secret schema" below).
    6. Flip `enableSops` in this file to true and rebuild.

  Secret schema (what to put in secrets/secrets.yaml)
  ---------------------------------------------------
    grafana-admin-pass:      "<strong-password>"
    nextcloud-admin-pass:    "<strong-password>"
    vaultwarden-admin-token: "<64-char-random>"
    miniflux-admin-user:     "admin"
    miniflux-admin-pass:     "<strong-password>"
    miniflux-api-token:      "<from-miniflux-ui>"
    ntfy-agent-token:        "<from-ntfy-cli>"
    ntfy-grafana-token:      "<from-ntfy-cli>"
    ghostfolio-api-token:    "<from-ghostfolio-ui>"
    restic-repo-password:    "<random-64-char>"

  Consumers
  ---------
  Downstream modules reference `config.sops.secrets.<name>.path`
  (a filesystem path to the decrypted value at runtime) — never inline
  the value into the Nix store.

  Fail-open mode
  --------------
  While `enableSops = false` this module only declares the sops.age
  key locations; no `sops.secrets` are registered so the eval works
  even before the encrypted file exists.
*/
{ lib, ... }:
let
  enableSops = false; # flip to true after bootstrap step 5.
  secretsFile = ../../secrets/secrets.yaml;
in
{
  sops = lib.mkMerge [
    {
      age = {
        keyFile = "/var/lib/sops-nix/host.age";
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        generateKey = false;
      };
    }

    (lib.mkIf enableSops {
      defaultSopsFile = secretsFile;
      defaultSopsFormat = "yaml";

      secrets = {
        # Web-UI admin passwords / API tokens.
        grafana-admin-pass = {
          owner = "grafana";
          group = "grafana";
          mode = "0400";
        };
        nextcloud-admin-pass = {
          owner = "nextcloud";
          group = "nextcloud";
          mode = "0400";
        };
        vaultwarden-admin-token = {
          owner = "vaultwarden";
          group = "vaultwarden";
          mode = "0400";
        };
        miniflux-admin-user = {
          owner = "miniflux";
          group = "miniflux";
          mode = "0400";
        };
        miniflux-admin-pass = {
          owner = "miniflux";
          group = "miniflux";
          mode = "0400";
        };

        # Agent tokens — mounted read-only into agent-* units via
        # ReadOnlyPaths in modules/agents/lib.nix.
        miniflux-api-token = {
          mode = "0400";
        };
        ghostfolio-api-token = {
          mode = "0400";
        };
        ntfy-agent-token = {
          mode = "0400";
        };
        ntfy-grafana-token = {
          owner = "grafana";
          group = "grafana";
          mode = "0400";
        };

        # Restic offsite backup.
        restic-repo-password = {
          mode = "0400";
        };
      };
    })
  ];
}
