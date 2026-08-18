-- core/autocmds.lua — Autocommands

local autocmd = vim.api.nvim_create_autocmd

-- Reload the buffer automatically when the file changes on disk.
autocmd({ "FocusGained", "BufEnter" }, {
	pattern = "*",
	command = "checktime",
})
