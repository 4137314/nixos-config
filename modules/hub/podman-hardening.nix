/*
  hub/podman-hardening.nix — Global systemd restart-limit guard for
  every podman container declared under
  `virtualisation.oci-containers.containers`.

  Why
  ---
  Podman OCI-container units default to `Restart = on-failure` with no
  upper bound. If a container crashes on startup (bad image tag,
  missing env file, DNS collision, corrupt volume, …) systemd will
  restart it forever — every ~10s — with each cycle:
    * spawning a fresh container namespace,
    * generating journal spam that drowns the real signals,
    * potentially blocking `multi-user.target` because
      `wantedBy = multi-user.target` on the failing unit prevents the
      target from reaching `active` and cascades into a stalled boot.

  This bit us in production: `podman-openbb.service` looped 98 times
  chasing a bad `docker.io/openbb/openbb:latest` image tag until we
  killed the switch by hand.

  What this module does
  ---------------------
  For every entry in `virtualisation.oci-containers.containers` we
  set two systemd unit-level options (NB: these live under
  `unitConfig`, NOT `serviceConfig` — a very common mistake):

    StartLimitBurst      = 3       # attempts allowed…
    StartLimitIntervalSec = 300    # …in a 5-minute window.

  Once the burst is exceeded, systemd stops trying and puts the unit
  in `failed` state with `Result: start-limit-hit`. The rest of the
  system continues to boot normally; the operator sees the failure
  in `systemctl --failed` and investigates on a coffee schedule.

  Sizing rationale: 3 in 5 min is aggressive enough to catch a
  transient network hiccup on image pull (retries succeed), but tight
  enough that a genuinely broken container gives up in ~90 seconds
  instead of an hour.

  Per-container override
  ----------------------
  If a specific container legitimately needs a higher burst (e.g. one
  that races with its DB sidecar on cold boot), override it in the
  container's own module with a normal `mkForce`:

    systemd.services."podman-<name>".unitConfig.StartLimitBurst =
      lib.mkForce 10;
*/
{ config, lib, ... }:
let
  containerNames = builtins.attrNames config.virtualisation.oci-containers.containers;

  # Applied to every podman-<name>.service.
  restartLimits = {
    unitConfig = {
      StartLimitBurst = 3;
      StartLimitIntervalSec = 300;
    };
  };
in
{
  systemd.services = lib.genAttrs (map (n: "podman-${n}") containerNames) (_: restartLimits);
}
