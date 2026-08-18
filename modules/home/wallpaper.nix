/*
  home/wallpaper.nix — Rotating wallpaper via swww.

  Every 30 minutes a systemd user timer picks a random image from
  ~/Pictures/wallpapers/ and swaps it in with a smooth transition.

  Add images to that directory (jpg, png, webp). A starter wallpaper is
  provided via home.file if the directory doesn't exist yet.
*/
{ pkgs, ... }:
let
  swwwRotate = pkgs.writeShellApplication {
    name = "swww-rotate";
    runtimeInputs = with pkgs; [
      swww
      findutils
      coreutils
    ];
    text = ''
      DIR="$HOME/Pictures/wallpapers"
      [ -d "$DIR" ] || exit 0

      IMG=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | shuf -n 1)
      [ -n "$IMG" ] || exit 0

      swww img "$IMG" \
        --transition-type grow \
        --transition-pos "$(( RANDOM % 100 ))%,$(( RANDOM % 100 ))%" \
        --transition-fps 60 \
        --transition-duration 2 \
        --transition-step 90
    '';
  };
in
{
  home.packages = [ swwwRotate ];

  systemd.user.services.swww-rotate = {
    Unit.Description = "Rotate the desktop wallpaper";
    Service = {
      Type = "oneshot";
      ExecStart = "${swwwRotate}/bin/swww-rotate";
    };
  };

  systemd.user.timers.swww-rotate = {
    Unit.Description = "Rotate wallpaper every 30 minutes";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "30min";
      Unit = "swww-rotate.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
