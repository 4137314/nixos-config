/*
  system/peripherals.nix — Printing (CUPS) and scanning (SANE).

  Scope
  -----
  This host has no Bluetooth radio, no microphone, and no external
  sensors, so the corresponding stacks (`hardware.bluetooth`, `blueman`,
  IIO) are intentionally NOT enabled here. Adding them later means
  dropping a new block in this file — one concern, one place.

  Printing (CUPS)
  ---------------
  CUPS + Avahi + mDNS browsing gives zero-config discovery of network
  printers (HP, Brother, Epson). The driver bundle covers the vast
  majority of consumer devices so most printers Just Work without
  manually installing a PPD.

  Scanners (SANE)
  ---------------
  Enabled for flatbed / all-in-one scanning via `simple-scan` or
  `xsane`. `sane-airscan` gives driverless network scanners; the HPLIP
  plug-in covers HP MFPs.

  Avahi
  -----
  `services.avahi` is already declared by `nas/samba.nix` for SMB
  advertisement; here we only extend it with `nssmdns4` (so `.local`
  hostname resolution works) and open its UDP port in the firewall.
*/
{ pkgs, ... }:
{
  hardware.sane = {
    enable = true;
    extraBackends = [
      pkgs.sane-airscan
      pkgs.hplipWithPlugin
    ];
  };

  services = {
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        hplip
        brlaser
        brgenml1lpr
        brgenml1cupswrapper
        cnijfilter2
      ];
    };

    # Extend the Avahi instance declared by nas/samba.nix.
    avahi = {
      openFirewall = true;
      nssmdns4 = true;
    };
  };
}
