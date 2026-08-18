/*
  ai/iot.nix — IoT + smart-home hardware bridges.

  Enabled bridges
  ---------------
  Mosquitto        MQTT broker on :1883, local-only.
  Zigbee2MQTT      Bridges a Zigbee USB coordinator (Sonoff ZBDongle-E /
                   Aeotec Z-Stick) → MQTT → Home Assistant.
  ESPHome          Native compilation server for ESP32/8266 firmware.
                   Web UI on :6052.

  Hardware requirements
  ---------------------
  Zigbee coordinator plugged into a USB port (persistent by-id path is
  more stable than /dev/ttyUSB0). Update `serial.port` after plugging:
    ls -la /dev/serial/by-id/    → pick usb-Silicon_Labs_… or usb-ITEAD_…

  First-run
  ---------
    1. Plug the Zigbee coordinator.
    2. Rebuild → z2m boots, web UI at http://127.0.0.1:8083.
       (Path already in use by Firefly III — this uses 8084 instead.)
    3. Permit-join in z2m UI to pair devices, then close permit-join.
    4. Add MQTT integration in Home Assistant → auto-discovers z2m
       devices.

  ESPHome
  -------
  Web UI: http://127.0.0.1:6052. Create devices declaratively in YAML,
  compile firmware, flash over-the-air.
*/
{ pkgs, ... }:
{
  services = {
    # ---------------------------------------------------------------------
    # MQTT broker — the bus every IoT service talks to.
    # ---------------------------------------------------------------------
    mosquitto = {
      enable = true;
      listeners = [
        {
          address = "127.0.0.1";
          port = 1883;
          settings.allow_anonymous = false;
          users.hass = {
            acl = [ "readwrite #" ];
            hashedPasswordFile = "/var/lib/mosquitto/hass.pw";
          };
          users.z2m = {
            acl = [
              "readwrite zigbee2mqtt/#"
              "readwrite homeassistant/#"
            ];
            hashedPasswordFile = "/var/lib/mosquitto/z2m.pw";
          };
        }
      ];
    };

    # ---------------------------------------------------------------------
    # Zigbee2MQTT — hardware bridge for Zigbee devices.
    # ---------------------------------------------------------------------
    zigbee2mqtt = {
      enable = true;
      settings = {
        permit_join = false;

        mqtt = {
          base_topic = "zigbee2mqtt";
          server = "mqtt://127.0.0.1:1883";
          user = "z2m";
          password = "!/var/lib/zigbee2mqtt/mqtt-password.yaml password";
        };

        serial = {
          # Update this after plugging your coordinator:
          # ls -la /dev/serial/by-id/
          port = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20240924102207-if00";
          adapter = "ember";
        };

        frontend = {
          port = 8084;
          host = "127.0.0.1";
        };

        advanced = {
          log_level = "info";
          log_output = [ "console" ];
          network_key = "GENERATE";
          pan_id = "GENERATE";
          ext_pan_id = "GENERATE";
          channel = 15;
        };

        device_options = {
          retain = true;
        };
      };
    };

    # ---------------------------------------------------------------------
    # ESPHome — firmware compilation + OTA update server.
    # ---------------------------------------------------------------------
    esphome = {
      enable = true;
      address = "127.0.0.1";
      port = 6052;
      openFirewall = false;
    };
  };

  # esptool for one-off flashing from the CLI.
  environment.systemPackages = [ pkgs.esptool ];

  # -------------------------------------------------------------------------
  # Pre-create state dirs + password placeholders.
  # -------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /var/lib/mosquitto  0700 mosquitto mosquitto -"
    "d /var/lib/zigbee2mqtt 0700 zigbee2mqtt zigbee2mqtt -"
  ];
}
