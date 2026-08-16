-- core/options.lua — Global Neovim options

local opt = vim.opt
local g   = vim.g

-- Leader key (must be set before lazy loads plugins)
g.mapleader = " "

-- Clipboard
opt.clipboard = "unnamedplus"

-- File handling
opt.swapfile  = false
opt.backup    = false
opt.undofile  = true
opt.autowrite = true
opt.autoread  = true
opt.hidden    = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.incsearch  = true
opt.hlsearch   = true

-- Performance
opt.timeoutlen = 500
opt.updatetime = 300

-- UI
opt.number      = true
opt.cursorline  = true
opt.signcolumn  = "yes"
opt.breakindent = true
opt.showbreak   = "↪"
opt.linebreak   = true

-- Completion
opt.completeopt = { "menuone", "noselect" }

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Folding (driven by nvim-treesitter)
opt.foldmethod = "expr"
opt.foldexpr   = "nvim_treesitter#foldexpr()"
opt.foldenable = false
