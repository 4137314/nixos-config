{ config, pkgs, inputs, ... }:

{
  home.username = "main";
  home.homeDirectory = "/home/main";

  home.packages = [
    # Ora 'inputs' sarà riconosciuto senza errori!
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.neovim-unwrapped

    pkgs.ripgrep
    pkgs.fd
    pkgs.tree-sitter
    pkgs.nodejs_22
    pkgs.python311
    pkgs.python311Packages.pynvim
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    
    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
    ];

    settings = {
      debug = {
        disable_logs = false; 
      };

      plugin = {
        hyprexpo = {
          columns = 5;                  
          gap_size = 15;                
          bg_col = "rgba(30, 30, 46, 0.7)"; 
          workspace_method = "center current"; 
          enable_gesture = true;        
          gesture_distance = 300;       
          gesture_positive = true;      
          animate_bar = true;           
          animate_background = true;    
          close_on_click = true;        
        };
      };
    };

    extraConfig = ''
      # See https://wiki.hyprland.org/Configuring/Monitors/
      monitor=HDMI-A-1, 2560x1440@60, 0x0, 1

      exec-once = hyprctl plugin load ${pkgs.hyprlandPlugins.hyprexpo}/lib/libhyprexpo.so

      exec-once = wl-paste --type text --watch cliphist store 
      exec-once = wl-paste --type image --watch cliphist store
      exec-once = waybar
      exec-once = hypridle
      exec-once = swww-daemon &
      exec-once = swww img ~/Pictures/wallpapers/sci-fi-landscape.jpg --transition-type center --transition-step 90
      exec-once = env GDK_BACKEND=wayland swayosd-server &

      env = XCURSOR_SIZE,24

      input {
          kb_layout = us
          follow_mouse = 1
          touchpad {
              natural_scroll = no
          }
          sensitivity = 0 
      }

      general {
          gaps_in = 5
          gaps_out = 20
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          layout = dwindle
          allow_tearing = false
      }

      decoration {
          rounding = 12 
          active_opacity = 0.93      
          inactive_opacity = 0.85    
          fullscreen_opacity = 1.0   
          blur {
              enabled = true
              size = 8               
              passes = 3             
              new_optimizations = true
              xray = true            
          }
      }

      blurls = ags
      blurls = wofi

      animations {
          enabled = yes
          bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }

      dwindle {
          pseudotile = yes 
          preserve_split = yes 
      }

      misc {
          force_default_wallpaper = 0 
          disable_hyprland_logo = true
      }

      $mainMod = SUPER

      bind = $mainMod, Q, exec, kitty
      bind = $mainMod, C, killactive, 
      bind = $mainMod, M, exit, 
      bind = $mainMod, E, exec, dolphin
      bind = $mainMod, V, togglefloating, 
      bind = $mainMod, R, exec, wofi --show drun
      bind = $mainMod, P, pseudo, 
      bind = $mainMod, J, togglesplit, 
      bind = $mainMod, F, fullscreen, 0 
      bind = $mainMod, Escape, workspace, previous

      bind = $mainMod, Tab, hyprexpo:expo, toggle
      bind = $mainMod, mouse:274, hyprexpo:expo, toggle

      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      binde = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
      binde = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
      bindl = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle

      bindl = , Pause, exec, loginctl lock-session && systemctl suspend
      bind = $mainMod, L, exec, hyprlock
    '';
  };

  home.stateVersion = "25.11";
}
