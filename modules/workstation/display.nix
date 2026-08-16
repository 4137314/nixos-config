_:

# ─────────────────────────────────────────────────────────────────────────────
# Display Manager: Ly (TUI, leggero, con animazione matrix).
# Hyprland è avviato da Ly tramite la sessione Home Manager.
# ─────────────────────────────────────────────────────────────────────────────
{
  services.displayManager.ly = {
    enable   = true;
    settings = {
      animation = "matrix";
      save      = true;
    };
  };

  # Portali XDG richiesti da Hyprland per screenshot, file picker, ecc.
  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];
}
