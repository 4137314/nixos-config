/*
  hub/audiobookshelf.nix — Self-hosted audiobook and podcast server.

  Libraries
  ---------
  Point at directories under /srv/nas/media/{audiobooks,podcasts} — these
  live on the Btrfs subvolume with snapper snapshots. Audiobookshelf watches
  for changes, imports metadata (author/narrator/series), fetches cover art.

  Clients
  -------
  Native iOS/Android apps, Progressive Web App on desktop. Handles resume
  position across devices.

  Access
  ------
  http://127.0.0.1:8112 direct, https://audio.nixos-hacker-box behind Caddy.

  On `dataDir`
  ------------
  The NixOS module in nixpkgs 25.11 has a bug: it prepends `/var/lib/` to
  the `dataDir` value when building `WorkingDirectory`, so passing an
  ABSOLUTE `dataDir` like `/var/lib/audiobookshelf` produces the broken
  `WorkingDirectory=/var/lib/var/lib/audiobookshelf` and the service
  crashes with `status=200/CHDIR`. We therefore DO NOT set `dataDir` and
  let the module use its own default (which is the correct
  `/var/lib/audiobookshelf`).

  Also override `StateDirectory=` to a relative name — the upstream sets
  the absolute form which systemd silently ignores, so the dir is never
  auto-created without this fix.

  First-run
  ---------
  1. Create the media directories (only needs to happen once):
       sudo install -d -o audiobookshelf -g media -m 0775 /srv/nas/media/audiobooks
       sudo install -d -o audiobookshelf -g media -m 0775 /srv/nas/media/podcasts
  2. Open the URL, create the admin user in the setup wizard.
  3. Add libraries pointing at the two directories above.
*/
{ lib, ... }:
{
  services.audiobookshelf = {
    enable = true;
    host = "127.0.0.1";
    port = 8112;
    # dataDir intentionally NOT set — see doc-comment above (upstream bug).
  };

  # Ensure the service account can read files owned by the media group.
  users.users.audiobookshelf.extraGroups = [ "media" ];

  # Force StateDirectory to a RELATIVE name so systemd auto-creates
  # /var/lib/audiobookshelf with the right owner before ExecStart.
  systemd.services.audiobookshelf.serviceConfig.StateDirectory = lib.mkForce "audiobookshelf";
}
