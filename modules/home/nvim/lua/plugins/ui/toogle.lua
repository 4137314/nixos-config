-- plugins/ui/toogle.lua — Colour scheme and floating terminal

return {
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size         = 20,
        open_mapping = [[<C-space>]],
        hide_numbers = true,
        direction    = "float",
        float_opts   = { border = "curved" },
      })
    end,
  },
}
