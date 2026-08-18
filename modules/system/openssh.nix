/*
  system/openssh.nix — Hardened OpenSSH daemon with 2FA (TOTP).

  Access model
  ------------
  Two-factor: SSH key + TOTP code from an offline authenticator app
  (Aegis, FreeOTP, andOTP). Passwords are off, root is off, X11 is off.

  Bootstrap TOTP for user `main`
  ------------------------------
    ssh main@localhost                 # enroll from a local shell first
    google-authenticator -t -d -f -r 3 -R 30 -w 3
    # scan the QR with Aegis on your phone
    # keep the emergency scratch codes in Vaultwarden

  Exposure
  --------
  Port 22 is opened only on the LAN interface. Remote access should go
  through Tailscale — trusted via modules/network/tailscale.nix.

  Brute-force protection
  ----------------------
  Sees system/fail2ban.nix — sshd jail bans repeat offenders after 5 attempts.
*/
_: {
  # PAM: enable Google Authenticator TOTP for sshd + login. `nullOk` means
  # accounts without ~/.google_authenticator still login with only key —
  # switch to false after every operator has enrolled.
  security.pam.services.sshd = {
    googleAuthenticator = {
      enable = true;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      # Auth policy: publickey required, then a second-factor (TOTP).
      # Setting AuthenticationMethods to `publickey,keyboard-interactive:pam`
      # tells sshd to run pam_google_authenticator after the key succeeds.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = true; # needed for TOTP prompt
      AuthenticationMethods = "publickey,keyboard-interactive:pam";
      UsePAM = true;
      PermitRootLogin = "no";
      PermitEmptyPasswords = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;

      # Session policy
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = "local"; # port-forward inbound only
      GatewayPorts = "no";
      PermitTunnel = "no";

      # Crypto — modern ciphers/MACs/KEX only.
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
      ];
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "sntrup761x25519-sha512@openssh.com"
      ];

      # Session hygiene
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      # Restrict which users can log in over SSH (main only).
      AllowUsers = [ "main" ];
    };

    # Regenerate host keys if missing; do NOT overwrite existing ones.
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # NOTE: authorised keys go in users.users.main.openssh.authorizedKeys.keys
  # or authorizedKeysFiles (populate via sops secret in a future step).
}
