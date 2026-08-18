/*
  ai/frigate.nix — NVR with real-time object detection on AMD GPU.

  What it does
  ------------
  Ingests RTSP streams from IP cameras. Uses YOLOv8 / SSDLite via ONNX +
  ROCm to detect person / car / package / animal / face in real-time.
  Events → snapshots + clips saved to /srv/nas/frigate. Home Assistant
  integration exposes each camera as a media_player + a set of binary
  sensors (person_detected, motion, etc.).

  Storage
  -------
  /srv/nas/frigate holds media (clips + snapshots). Retention 30 days
  by default (configure per-camera in the YAML).

  Access
  ------
  http://127.0.0.1:5001 direct, https://nvr.nixos-hacker-box behind Caddy.

  Configuration
  -------------
  Camera details are written to /var/lib/frigate/config.yml — the module
  seeds a placeholder that you edit through the web UI (Frigate 0.13+
  supports config editing in-browser).
*/
_: {
  services.frigate = {
    enable = true;
    hostname = "nvr.nixos-hacker-box";
    settings = {
      mqtt = {
        enabled = true;
        host = "127.0.0.1";
        port = 1883;
        user = "hass";
        password = "!ENV MQTT_PASSWORD";
        topic_prefix = "frigate";
      };

      database.path = "/var/lib/frigate/frigate.db";

      detectors.rocm = {
        type = "rocm";
        device = "0";
      };

      model = {
        path = "/config/models/yolov8n.onnx";
        input_tensor = "nchw";
        input_pixel_format = "bgr";
        width = 320;
        height = 320;
      };

      objects = {
        track = [
          "person"
          "car"
          "dog"
          "cat"
          "package"
        ];
        filters.person = {
          min_score = 0.6;
          threshold = 0.7;
        };
      };

      record = {
        enabled = true;
        retain.days = 3;
        events = {
          retain = {
            default = 30;
            mode = "motion";
          };
        };
      };

      snapshots = {
        enabled = true;
        retain.default = 30;
      };

      # Camera stubs — replace with real RTSP feeds. Delete these two
      # blocks to start with an empty config, then add cameras via the
      # web UI (Frigate 0.14+).
      cameras = { };

      ffmpeg = {
        hwaccel_args = "preset-vaapi";
      };
    };
  };

  # Frigate writes clips to /srv/nas/frigate/media (bind-mounted).
  systemd.tmpfiles.rules = [
    "d /srv/nas/frigate       0755 frigate frigate -"
    "d /srv/nas/frigate/media 0755 frigate frigate -"
  ];
}
