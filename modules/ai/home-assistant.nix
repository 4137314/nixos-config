/*
  ai/home-assistant.nix — Home Assistant hub (software-only automations).

  Scope on this host
  ------------------
  This box has no microphone, no Bluetooth radio and no external
  physical sensors (Zigbee, Z-Wave, IIO, ESPHome...). HA is therefore
  configured as a *software* hub only:
    • sun / workday triggers                      (time-of-day flows)
    • weather via the free `met.no` integration   (no hardware needed)
    • ntfy fan-out (already the sink for Grafana / restic / fail2ban)
    • LLM chat via the "Assist" pipeline → Ollama (text-only, no STT)
    • webhook / REST inbound from n8n, changedetection, custom agents

  When the box eventually gets an IoT stack, re-enable
  `modules/ai/iot.nix` and add the matching `extraComponents`
  (zha, zwave_js, esphome, mqtt discovery, bluetooth) below.

  Access
  ------
  http://127.0.0.1:8123 direct, https://ha.nixos-hacker-box behind Caddy.

  First-run
  ---------
  1. Open the URL and create the owner user.
  2. Settings → Integrations → Add integration → Ollama
       URL:    http://127.0.0.1:11434
       Model:  qwen2.5:14b     (or llama3.2:3b for speed)
       Prompt: see modules/agents/prompts/home-assistant.md
  3. Settings → Voice assistants → Create pipeline
       STT:  (none — no microphone on this host)
       TTS:  Piper           (http://127.0.0.1:10201/v1)
       Conv: Ollama (from step 2)
     The pipeline is text-in / voice-out; use it from the web UI or
     browser-side speech recognition on a client device.
*/
_: {
  services.home-assistant = {
    enable = true;
    openFirewall = false;
    configWritable = true;

    extraComponents = [
      "default_config"
      "met"
      "radio_browser"
      "ollama"
      "piper"
      "wake_on_lan"
      "prometheus"
      "webhook"
      "shell_command"
      "rest_command"
      "notify"
      "ntfy"
      "waze_travel_time"
      "sun"
      "workday"
    ];

    config = {
      # `default_config` pulls in ~30 built-in integrations.
      default_config = { };

      homeassistant = {
        name = "HackerBox";
        latitude = 45.4642; # Milano — cambia al tuo comune
        longitude = 9.19;
        elevation = 120;
        unit_system = "metric";
        currency = "EUR";
        country = "IT";
        time_zone = "Europe/Rome";
        temperature_unit = "C";
      };

      http = {
        server_host = [
          "127.0.0.1"
          "::1"
        ];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      # Prometheus scrape endpoint at /api/prometheus.
      prometheus = { };

      # Expose the "sun" trigger and workday sensor to automations.
      sun = { };

      # Wire ntfy as a notify target. Automations can then do
      # `service: notify.hub` with title/message payload.
      notify = [
        {
          name = "hub";
          platform = "rest";
          resource = "http://127.0.0.1:2586/system";
          method = "POST_JSON";
          title_param_name = "title";
          message_param_name = "message";
        }
      ];

      logger = {
        default = "warning";
        logs."homeassistant.core" = "info";
      };

      recorder = {
        purge_keep_days = 30;
        commit_interval = 15;
      };
    };
  };

  # HA reads/writes `/var/lib/hass` by default. Pre-create it so it can
  # later become a Btrfs subvolume or a bind-mount to /srv/nas.
  systemd.tmpfiles.rules = [
    "d /var/lib/hass 0700 hass hass -"
  ];
}
