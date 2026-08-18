-- init.lua — Neovim entry point
-- Managed declaratively via NixOS (modules/home/neovim.nix).
-- Edit this file here; the rebuild will symlink it to ~/.config/nvim/init.lua.

-- Bootstrap lazy.nvim (downloaded to ~/.local/share/nvim/lazy/lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		lazyrepo,
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Signal to plugins that Nerd Font glyphs are available.
vim.g.have_nerd_font = true

-- Core configuration modules (options, mappings, autocommands)
require("core.options")
require("core.keymaps")
require("core.autocmds")

-- Plugin manager — imports all specs from lua/plugins/
require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
	defaults = { lazy = false },
	rocks = {
		-- Disable LuaRocks to avoid conflicts with the Nix-managed Lua environment.
		enabled = false,
		hererocks = false,
	},
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
