/*
  hub/trilium.nix — Personal knowledge base (linked notes, wiki, tags).

  Trilium Next is the actively-maintained successor of trilium-notes,
  with hierarchical notes, cloned notes, scripting, note relations,
  attributes, and a native mobile client.

  Complementarity
  ---------------
  Memos → micro-posts, twitter-like.
  SilverBullet → markdown files-first, agent-driven, code-embed.
  Trilium → structured knowledge tree, wiki, project archives.

  Access
  ------
  http://127.0.0.1:8082 direct, https://wiki.nixos-hacker-box behind Caddy.

  First-run
  ---------
  Open the URL → set the master password. All notes are encrypted at
  rest with a key derived from that password (Trilium's own scheme).
*/
_: {
  services.trilium-server = {
    enable = true;
    host = "127.0.0.1";
    port = 8082;
    dataDir = "/var/lib/trilium";
  };
}
