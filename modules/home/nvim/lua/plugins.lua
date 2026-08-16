-- plugins.lua — Root plugin spec; imports sub-directories.

return {
  { import = "plugins.ui" },
  -- { import = "plugins.lsp" },  -- LSP configuration (not yet enabled)
  { import = "plugins.tools" },
}
