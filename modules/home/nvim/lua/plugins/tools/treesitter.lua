-- plugins/tools/treesitter.lua — Syntax tree parsing and highlighting
-- Note: parsers are pre-installed by Nix (tree-sitter package); ensure_installed
-- lists them explicitly so the plugin does not try to compile them at runtime.

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local ok, configs = pcall(require, "nvim-treesitter.configs")
		if not ok then
			return
		end

		configs.setup({
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"query",
				"nix",
				"python",
				"c",
				"bash",
				"markdown",
			},
			sync_install = false,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},
			indent = { enable = true },
		})
	end,
}
