_:

# ─────────────────────────────────────────────────────────────────────────────
# Audio: PipeWire con profilo a bassa latenza.
# jack.enable = true permette agli host JACK di usare il bridge PipeWire.
# ─────────────────────────────────────────────────────────────────────────────
{
  # Evita il risparmio energetico HDA che causa "click" e silenzi
  boot.kernelParams = [ "snd_hda_intel.power_save=0" ];

  security.rtkit.enable = true;

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate"        = 48000;
        "default.clock.quantum"     = 512;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };
}
