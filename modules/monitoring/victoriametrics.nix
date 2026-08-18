/*
  monitoring/victoriametrics.nix — Long-term metric storage.

  Why alongside Prometheus
  ------------------------
  Prometheus is kept for its 30-day tactical window (fast queries, alert
  eval). VictoriaMetrics receives a `remote_write` stream from Prometheus
  and stores it forever with much better compression (~10x smaller than
  Prom TSDB at equal fidelity).

  Grafana gets a second datasource pointing at VM — dashboards can pick
  between "last 30 days" (Prom) and "all time" (VM).

  Retention
  ---------
  `--retentionPeriod=5y` — 5 years. Adjust if disk fills faster than
  expected (typical: ~1 GB/year for this workload).

  Storage
  -------
  /var/lib/victoriametrics on the system SSD. VM's on-disk format is
  covered by restic — bulk metric data isn't essential but the config
  and small state is.
*/
_: {
  services = {
    victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
      retentionPeriod = "5y";
      extraOptions = [
        "-storageDataPath=/var/lib/victoriametrics"
        "-memory.allowedPercent=25"
        "-search.maxQueryDuration=60s"
        "-search.latencyOffset=15s"
      ];
    };

    # Feed VM from Prometheus.
    prometheus.remoteWrite = [
      {
        url = "http://127.0.0.1:8428/api/v1/write";
        queue_config = {
          capacity = 10000;
          max_shards = 4;
        };
      }
    ];

    # Grafana datasource — merges with Prometheus + Loki declared elsewhere.
    grafana.provision.datasources.settings.datasources = [
      {
        name = "VictoriaMetrics";
        type = "prometheus";
        access = "proxy";
        url = "http://127.0.0.1:8428";
        uid = "victoriametrics";
        jsonData = {
          prometheusType = "Prometheus";
          timeInterval = "30s";
        };
      }
    ];
  };
}
