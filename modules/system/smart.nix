/*
  system/smart.nix — smartd disk health monitoring with ntfy on failure.

  Coverage
  --------
  Auto-detect all attached disks (autodetect = true). smartd runs SMART
  self-tests on a background schedule:
    - short self-test every day at 03:00
    - long  self-test every Sunday at 04:15

  On any SMART failure, a helper script pushes to ntfy topic `system`
  with high priority. Prometheus + Grafana still keep the running
  telemetry — this is a fast-path alert.

  smartctl output is also parsed by the smartctl_exporter (see
  modules/monitoring/observability.nix) which powers the SmartFailing
  alert. Two independent paths → less chance of missing a fault.
*/
{ pkgs, ... }:
{
  services.smartd = {
    enable = true;
    autodetect = true;

    defaults.autodetected =
      "-a -o on -S on -n standby,q "
      + "-s (S/../.././03|L/../../7/04) "
      + "-W 4,45,55 " # notify on ΔT >4, warn 45, crit 55
      + "-m <nomailer> -M exec ${pkgs.writeShellScript "smartd-notify" ''
        DEV="$SMARTD_DEVICE"
        MSG="$SMARTD_MESSAGE"
        ${pkgs.curl}/bin/curl -sf -X POST http://127.0.0.1:2586/system \
          -H "Title: SMART fault on $DEV" \
          -H "Priority: high" \
          -H "Tags: rotating_light,floppy_disk" \
          --data "$MSG"
      ''}";
  };
}
