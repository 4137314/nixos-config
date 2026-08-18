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

    dataDir = "/var/lib/audiobookshelf";
  };

  # Ensure the service account can read files owned by the media group.
  users.users.audiobookshelf.extraGroups = [ "media" ];

  # The upstream module sets `WorkingDirectory=` to `dataDir` but does NOT
  # create the directory, so systemd fails with `status=200/CHDIR` on
  # first boot. Pre-create it as root — the audiobookshelf user may not
  # yet exist when `systemd-tmpfiles-setup` first runs; the service itself
  # is started with the correct uid and will chown its own subtree.
  systemd.tmpfiles.rules = [
    "d /var/lib/audiobookshelf 0755 root root -"
  ];

  # The upstream module sets `StateDirectory = "/var/lib/audiobookshelf"`
  # (a full path). systemd rejects absolute paths for `StateDirectory=`
  # and silently skips creating the directory — hence the `status=200/CHDIR`
  # failure on first boot. Override with the correct RELATIVE form so
  # systemd creates and chowns the directory before ExecStart.
  systemd.services.audiobookshelf.serviceConfig.StateDirectory = lib.mkForce "audiobookshelf";
}
