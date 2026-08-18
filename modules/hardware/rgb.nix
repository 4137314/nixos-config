/*
  hardware/rgb.nix — OpenRGB LED controller with I2C/SMBus access.

  Kernel modules
  --------------
  i2c-dev    Character device interface for I2C bus access from userspace.
  i2c-piix4  SMBus controller for AMD chipsets.
  i2c-i801   SMBus controller for Intel chipsets.

  The `acpi_enforce_resources=lax` boot parameter relaxes ACPI resource
  ownership checks, which is required on many consumer boards where the
  firmware claims exclusive access to the I2C buses used by RGB hardware.

  The udev rule grants the `i2c` group read/write access to all I2C devices,
  allowing OpenRGB to run without root privileges (user must be in group i2c).
*/
_: {
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];
  boot.kernelModules = [
    "i2c-dev"
    "i2c-piix4"
    "i2c-i801"
  ];

  services.hardware.openrgb.enable = true;

  services.udev.extraRules = ''
    # Grant the i2c group access to SMBus/I2C devices (required by OpenRGB)
    SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"
  '';
}
