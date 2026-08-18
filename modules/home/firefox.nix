/*
  home/firefox.nix — Firefox with privacy-first policy defaults.

  Policies (enforced by policies.json)
  ------------------------------------
  Disable telemetry, Pocket, Firefox Home cards, sponsored top-sites, and the
  "Firefox View" tab. Enterprise policies survive updates and cannot be
  overridden by the user profile.

  User prefs (overrides on top of policies)
  -----------------------------------------
  browser.startup.page = 3        Reopen previous session on start.
  privacy.donottrackheader        On.
  network.trr.mode = 5            Explicitly do not use Mozilla DoH — the
                                  system already resolves via AdGuard.

  Profile
  -------
  A single named profile `main` — matches the OS user for clarity. Extensions
  are NOT declared here: policy blocks the extension store from making them
  auto-update behind our back, but manual install still works.
*/
_: {
  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = false;
      DisableFormHistory = true;
      DontCheckDefaultBrowser = true;
      DisplayBookmarksToolbar = "newtab";
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
      };
      SearchSuggestEnabled = false;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      Preferences = {
        "browser.tabs.firefox-view" = {
          Value = false;
          Status = "locked";
        };
        "browser.newtabpage.activity-stream.feeds.section.topstories" = {
          Value = false;
          Status = "locked";
        };
        "network.trr.mode" = {
          Value = 5;
          Status = "locked";
        };
        "privacy.donottrackheader.enabled" = {
          Value = true;
          Status = "default";
        };
      };
    };

    profiles.main = {
      id = 0;
      isDefault = true;

      settings = {
        "browser.startup.page" = 3;
        "browser.aboutConfig.showWarning" = false;
        "browser.download.useDownloadDir" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "extensions.pocket.enabled" = false;
        "signon.rememberSignons" = false;
      };
    };
  };
}
