/*
  hardware/gpu-amd.nix — AMD GPU with ROCm compute + Wayland acceleration.

  Assumed hardware: RDNA2/RDNA3 discrete GPU with ~8 GB VRAM.
  Adjust `AMD_TARGET` in modules/ai/ollama.nix if the GPU is very old
  or very new (Ollama needs to match HSA_OVERRIDE_GFX_VERSION).

  What this enables
  -----------------
    - amdvlk + Mesa RADV Vulkan drivers (game + compute)
    - 32-bit graphics libraries (Steam, Wine)
    - ROCm HIP compute stack for Ollama / PyTorch / llama.cpp
    - Video acceleration (VAAPI/VDPAU) for Jellyfin + Firefox

  Kernel
  ------
  amdgpu is loaded implicitly by hardware-configuration.nix; here we
  just make sure the userland is complete and the render group exists.

  Groups
  ------
  User `main` must be in `video` and `render` — already set in
  modules/system/users.nix.
*/
{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # ROCm compute stack (OpenCL + HIP).
      rocmPackages.clr
      rocmPackages.clr.icd

      # VA-API accel (Jellyfin transcode fallback if VAAPI isn't in NVENC path)
      libvdpau-va-gl
      libva
      libva-vdpau-driver

      # Vulkan — RADV (Mesa) is enabled by default; amdvlk is deprecated.
      mesa
    ];
  };

  # ROCm sysadmin utility — inspect the GPU from CLI.
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    radeontop
    libva-utils
    vulkan-tools
    clinfo
  ];

  # Some ROCm workloads need /dev/kfd + /dev/dri writable by the `render` group.
  services.udev.extraRules = ''
    # AMD GPU compute devices — accessible to the `render` group.
    KERNEL=="kfd", GROUP="render", MODE="0660"
    SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0660"
  '';

  # OpenCL platform search path — helps Blender / darktable / GIMP find ROCm.
  environment.sessionVariables = {
    OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors/";
    ROC_ENABLE_PRE_VEGA = "1";
  };
}
