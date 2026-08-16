_:

# ─────────────────────────────────────────────────────────────────────────────
# RGB: OpenRGB con accesso I2C/SMBus per il controllo hardware dei LED.
# acpi_enforce_resources=lax è necessario su alcuni chipset AMD/Intel.
# ─────────────────────────────────────────────────────────────────────────────
{
  boot.kernelParams  = [ "acpi_enforce_resources=lax" ];
  boot.kernelModules = [ "i2c-dev" "i2c-piix4" "i2c-i801" ];

  services.hardware.openrgb.enable = true;

  services.udev.extraRules = ''
    # Permessi I2C/SMBus per OpenRGB (gruppo i2c)
    SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"
  '';
}
