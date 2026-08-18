/*
  hardware/audio.nix — PipeWire audio stack with low-latency profile.

  Deployment scope
  ----------------
  Output-only. The host has no microphone: capture devices, if any,
  will still be enumerated by PipeWire (that is harmless) but no
  compatibility bridge for STT / voice-assistant capture is wired
  anywhere else in the flake.

  Backends enabled
  ----------------
    ALSA         native ALSA + 32-bit support for legacy apps
    PulseAudio   compatibility bridge for libpulse clients
    JACK         low-latency bridge for pro-audio software

  Clock profile
  -------------
    rate     48 000 Hz
    quantum  512 frames   ≈ 10.7 ms   — balanced latency / stability
    min      32           real-time floor
    max      1024         ceiling under load

  Kernel workaround
  -----------------
  `snd_hda_intel.power_save=0` disables the HDA codec power-saving
  mode that causes audible clicks and dropouts on many Ryzen boards.
*/
_: {
  boot.kernelParams = [ "snd_hda_intel.power_save=0" ];

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
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
