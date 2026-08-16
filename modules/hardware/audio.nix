/*
  hardware/audio.nix — PipeWire audio stack with low-latency profile.

  Backends enabled
  ----------------
  ALSA     Native ALSA with 32-bit support for legacy applications.
  PulseAudio Compatibility layer for applications that use libpulse.
  JACK     Bridge for low-latency professional audio software.

  Clock profile
  -------------
  Rate:    48 000 Hz
  Quantum: 512 frames (~10.7 ms at 48 kHz) — balanced latency/stability.
  Min:     32 frames  — floor for real-time clients.
  Max:     1024 frames — ceiling under load.

  The `snd_hda_intel.power_save=0` kernel parameter disables the HDA
  codec power-saving mode that causes audible clicks and dropouts.
*/
_:
{
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
