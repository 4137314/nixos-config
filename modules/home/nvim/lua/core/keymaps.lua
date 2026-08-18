-- core/keymaps.lua — Global key mappings

local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Terminal splits
map("n", "<leader>ot", ":split | terminal<CR>", opts)
map("n", "<leader>vt", ":vsplit | terminal<CR>", opts)
