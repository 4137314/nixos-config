-- avante.nvim — Cursor-like AI assistant, wired to local Ollama.
--
-- Provider: openai-compatible (Ollama exposes /v1). No cloud traffic.
--
-- Keybinds (defaults):
--   <leader>aa   ask the assistant about the buffer
--   <leader>ae   edit the current selection with a prompt
--   <leader>ar   refresh the assistant answer
--   <leader>at   toggle the assistant sidebar
--
-- Model config uses qwen2.5-coder:14b (via Ollama on 127.0.0.1:11434).

return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	build = "make",
	opts = {
		provider = "openai",
		openai = {
			endpoint = "http://127.0.0.1:11434/v1",
			model = "qwen2.5-coder:14b",
			api_key_name = "OLLAMA_KEY", -- Ollama ignores auth; env var can be empty
			timeout = 60000,
			temperature = 0.15,
			max_tokens = 8192,
		},
		behaviour = {
			auto_suggestions = false, -- opt-in via <leader>ai
			auto_apply_diff_after_generation = false,
			support_paste_from_clipboard = true,
		},
		windows = {
			position = "right",
			width = 40,
			sidebar_header = { align = "center", rounded = true },
		},
		mappings = {
			ask = "<leader>aa",
			edit = "<leader>ae",
			refresh = "<leader>ar",
			toggle = { default = "<leader>at" },
		},
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		-- Optional rich rendering:
		"MeanderingProgrammer/render-markdown.nvim",
	},
}
