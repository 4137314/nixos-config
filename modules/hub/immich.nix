/*
  hub/immich.nix — Self-hosted photo library with ML face + object recognition.

  Why Immich
  ----------
  Google Photos-class UX self-hosted: face grouping, object/scene detection,
  automatic map view from EXIF, timeline scrubbing, mobile auto-upload.

  Storage
  -------
  Photos live in /srv/nas/immich (Btrfs subvolume — add to nas/storage.nix
  before enabling this module). Postgres + Redis are managed by the module.

  Compute
  -------
  Machine-learning uses the CPU by default. For large libraries consider a
  GPU passthrough (`services.immich.machine-learning.enable = true` + CUDA
  driver, out of scope here).

  Access
  ------
  http://127.0.0.1:2283 direct, https://photos.nixos-hacker-box behind Caddy.
  Mobile app: log in with the URL above.

  First-run
  ---------
  1. Create the Btrfs subvolume (once):
       sudo btrfs subvolume create /srv/nas/@immich
       # Add fileSystems entry mirroring @nextcloud to modules/nas/storage.nix.
  2. Ensure the immich user can write there (module creates the user):
       sudo install -d -o immich -g immich -m 750 /srv/nas/immich
  3. Open the URL → create the admin account in the setup wizard.
  4. Install the Immich mobile app on Pixel 9a → point at the URL, enable
     background upload of the Camera folder.
*/
_: {
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    port = 2283;
    mediaLocation = "/srv/nas/immich";

    # Local Postgres + Redis dedicated to Immich.
    database.createDB = true;
    redis.enable = true;

    # ML on-CPU (change to true + set accelerator if a GPU is available).
    machine-learning.enable = true;
  };
}
