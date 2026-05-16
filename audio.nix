{ config, lib, pkgs, ... }:

{
  boot.kernelParams = [ "snd_hda_intel.power_save=0" ];
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };
}
