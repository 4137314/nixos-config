/*
  hub/navidrome.nix — Self-hosted music streaming (Subsonic API compatible).

  Why Navidrome
  -------------
  Fast Go binary, Subsonic API means any Subsonic client works: DSub, play:Sub,
  Feishin, Symfonium, Sonixd, etc. Better than Jellyfin for music-first use:
  fast scanning of large libraries, gapless playback, smart playlists.

  Library
  -------
  /srv/nas/media/music — same Btrfs subvolume as films/tv, so snapper covers it.

  Access
  ------
  http://127.0.0.1:4533 direct, https://music.nixos-hacker-box behind Caddy.

  First-run
  ---------
  Open the URL → create the admin user. Add other users via the admin UI
  (one login per family member, per-user playlists and stats).
*/
_: {
  services.navidrome = {
    enable = true;
    openFirewall = false;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      BaseUrl = "https://music.nixos-hacker-box";

      MusicFolder = "/srv/nas/media/music";
      DataFolder = "/var/lib/navidrome";

      ScanSchedule = "@every 6h";
      SessionTimeout = "72h";
      EnableGravatar = true;
      EnableStarRating = true;

      LastFM.Enabled = false;
      Spotify.Enabled = false;
    };
  };

  users.users.navidrome.extraGroups = [ "media" ];
}
