/*
  hub/paperless.nix — Self-hosted document management with OCR + tagging.

  Purpose
  -------
  Point at a `consume/` directory (Syncthing folder from phone, scanner
  auto-drop, email attachment forward). Paperless OCRs every incoming PDF,
  extracts text, auto-tags by matching rules, and files everything.

  Storage layout (on Btrfs, snapper-covered)
  ------------------------------------------
  /srv/nas/paperless/consume/     drop new documents here
  /srv/nas/paperless/media/       archived documents (immutable)
  /srv/nas/paperless/data/        SQLite / search index

  Access
  ------
  http://127.0.0.1:28981 direct, https://docs.nixos-hacker-box behind Caddy.

  First-run
  ---------
  1. Create the directory tree:
       sudo install -d -o paperless -g paperless -m 750 \
         /srv/nas/paperless/consume \
         /srv/nas/paperless/media \
         /srv/nas/paperless/data
  2. Provision the admin password:
       echo -n "<StrongPassword>" | sudo tee /var/lib/paperless/admin-pass
       sudo chmod 640 /var/lib/paperless/admin-pass
       sudo chown paperless:paperless /var/lib/paperless/admin-pass
  3. First switch: Django migrates the DB and creates the admin user.

  OCR languages
  -------------
  Italian + English by default — extend `PAPERLESS_OCR_LANGUAGES` in
  `extraConfig` if you scan documents in more languages.
*/
_: {
  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28981;
    dataDir = "/srv/nas/paperless/data";
    mediaDir = "/srv/nas/paperless/media";
    consumptionDir = "/srv/nas/paperless/consume";
    consumptionDirIsPublic = false;
    passwordFile = "/var/lib/paperless/admin-pass";

    settings = {
      PAPERLESS_URL = "https://docs.nixos-hacker-box";
      PAPERLESS_OCR_LANGUAGES = "ita eng";
      PAPERLESS_OCR_LANGUAGE = "ita+eng";
      PAPERLESS_TIME_ZONE = "Europe/Rome";
      PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_CONSUMER_POLLING = 60;
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    };
  };
}
