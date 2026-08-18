/*
  security/wordlists.nix — Wordlists and dictionaries used by pentest tools.

  Layout
  ------
  All wordlists land under /var/lib/wordlists, symlinked into the traditional
  /usr/share/wordlists path many tools expect. Directory is world-readable
  (they are, after all, published wordlists).

  Sources
  -------
  SecLists     Aggregated collections (usernames, passwords, discovery,
               fuzzing payloads, WEB shells). The go-to for bug-bounty work.
  rockyou      The classic cracking dictionary.
  dirb / dirbuster wordlists   Ship with their respective packages under
               $out/share/wordlists — already available via dirb/gobuster.

  Aliases live in modules/workstation/shell.nix; a common one:
    export WORDLISTS=/var/lib/wordlists

  Storage footprint
  -----------------
  SecLists is ~1.2 GB decompressed. rockyou.txt is ~130 MB. Both fit comfortably
  on the NVMe. Not backed up (rebuildable from source).
*/
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    seclists
    wordlists
  ];

  # Convenience symlinks: /usr/share/wordlists/{SecLists,rockyou.txt}.
  # Many pentest tools default to /usr/share/wordlists — we mirror the layout
  # rather than teach every tool where nix stashed the files.
  systemd.tmpfiles.rules = [
    "d /usr/share/wordlists 0755 root root -"
    "L+ /usr/share/wordlists/SecLists  - - - - ${pkgs.seclists}/share/seclists"
  ];

  # Shell hint — pentesters rely on this env var.
  environment.sessionVariables.WORDLISTS = "/usr/share/wordlists";
}
