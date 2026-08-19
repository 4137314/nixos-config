/*
  agents/personal/default.nix — Life-facing agents.

  Members
  -------
    weekly-reflection    Sundays   past-week git + calendar + note diff → LLM reflection
    document-classifier  hourly    watches Nextcloud Inbox → auto-tags docs
    bookmark-summariser  hourly    new Karakeep bookmarks → LLM abstract
    calendar-briefer     mornings  Nextcloud calendar → morning briefing → ntfy
    health-nudger        daily     Home Assistant health sensors → LLM prompt

  All agents run as unprivileged `agent-<name>` users with a hardened
  sandbox and publish lifecycle events on the observatory bus.
*/
_: {
  imports = [
    ./weekly-reflection.nix
    ./document-classifier.nix
    ./bookmark-summariser.nix
    ./calendar-briefer.nix
    ./health-nudger.nix
  ];
}
