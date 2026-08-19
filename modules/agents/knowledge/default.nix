/*
  agents/knowledge/default.nix — Cross-service RAG pipelines.

  Currently one member: `rag-indexer` walks the union of {Nextcloud
  Notes, Karakeep bookmarks, Memos, Silverbullet, personal git repos}
  and pushes chunks into a dedicated Qdrant collection so agents in
  `personal/` and `ops/` can retrieve user context at inference time.

  This is distinct from `observatory/rag.nix` — that one indexes the
  MACHINE (config + reports + logs). Together the two collections give
  agents both self-knowledge (observatory) and user-knowledge
  (knowledge).
*/
_: {
  imports = [
    ./rag-indexer.nix
  ];
}
