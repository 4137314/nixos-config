{ config, lib, pkgs, ... }:

{
  boot.kernelParams = [ "acpi_enforce_resources=lax" "i2c-dev" ];
  boot.kernelModules = [ "i2c-dev" "i2c-piix4" "i2c-i801" ];

  services.hardware.openrgb.enable = true;

  services.udev.extraRules = ''
    # Permessi I2C/SMBus per OpenRGB
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"
    SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"
  '';
}
