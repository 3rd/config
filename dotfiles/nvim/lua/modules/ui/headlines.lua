local shared_config = {
	headline_highlights = { "Headline1", "Headline2", "Headline3", "Headline4", "Headline5", "Headline6" },
	codeblock_highlight = "CodeBlock",
	dash_highlight = "Dash",
	dash_string = "-",
	doubledash_highlight = "DoubleDash",
	doubledash_string = "=",
	quote_highlight = "Quote",
	quote_string = "┃",
	fat_headlines = true,
	fat_headline_upper_string = "▄",
	fat_headline_lower_string = "▀",
}

local syslang_headline_highlights = {
	"SyslangHeadline1",
	"SyslangHeadline2",
	"SyslangHeadline3",
	"SyslangHeadline4",
	"SyslangHeadline5",
	"SyslangHeadline6",
}

local syslang_headline_query_text = [[
              [
                (heading_1_marker)
                (heading_2_marker)
                (heading_3_marker)
                (heading_4_marker)
                (heading_5_marker)
                (heading_6_marker)
              ] @headline

              (horizontal_rule) @dash
              (double_horizontal_rule) @doubledash
              (banner) @quote
              (code_block_content) @codeblock
            ]]
local syslang_headline_query = nil

local get_syslang_headline_query = function()
	if syslang_headline_query then
		return syslang_headline_query
	end

	local ok, query = pcall(vim.treesitter.query.parse, "syslang", syslang_headline_query_text)
	if not ok then
		return nil
	end

	syslang_headline_query = query
	return query
end

local syslang_headline_group = vim.api.nvim_create_augroup("syslang_headline_signs", { clear = true })
local syslang_render_namespace = vim.api.nvim_create_namespace("syslang_render")
local SYSLANG_HEADLINE_RENDER_DEBOUNCE_MS = 40

local get_query_match_node = function(node)
	if type(node) ~= "table" then
		return node
	end
	return node[#node]
end

local get_line = function(bufnr, row)
	return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
end

local is_blank_line = function(bufnr, row)
	return get_line(bufnr, row) == ""
end

local is_heading_line = function(bufnr, row)
	return get_line(bufnr, row):match("^%s*#+%s") ~= nil
end

local is_shared_heading_gap = function(bufnr, row)
	if row <= 0 or row >= vim.api.nvim_buf_line_count(bufnr) - 1 then
		return false
	end

	return is_blank_line(bufnr, row) and is_heading_line(bufnr, row - 1) and is_heading_line(bufnr, row + 1)
end

local set_syslang_headline_gutter_row = function(bufnr, rows, row, char, hl_group, margin_char, margin_hl_group)
	if row < 0 or row >= vim.api.nvim_buf_line_count(bufnr) then
		return
	end

	rows[row + 1] = {
		char = char,
		hl = hl_group,
		margin_char = margin_char,
		margin_hl = margin_hl_group,
	}
end

local set_syslang_headline_text_row = function(bufnr, row, text, hl_group)
	if row < 0 or row >= vim.api.nvim_buf_line_count(bufnr) then
		return
	end

	vim.api.nvim_buf_set_extmark(bufnr, syslang_render_namespace, row, 0, {
		virt_text = { { text, hl_group } },
		virt_text_pos = "overlay",
		virt_text_win_col = 0,
		hl_mode = "combine",
	})
end

local set_syslang_codeblock = function(bufnr, node, left_offset)
	local start_row, _, end_row, end_col = node:range()
	if end_col > 0 then
		end_row = end_row + 1
	end

	vim.api.nvim_buf_set_extmark(bufnr, syslang_render_namespace, start_row, 0, {
		end_col = 0,
		end_row = end_row,
		hl_group = shared_config.codeblock_highlight,
		hl_eol = true,
	})

	local _, padding = get_line(bufnr, start_row):find("^ +")
	local codeblock_padding = math.max((padding or 0) - left_offset, 0)
	if codeblock_padding == 0 then
		return
	end

	for row = start_row, end_row - 1 do
		vim.api.nvim_buf_set_extmark(bufnr, syslang_render_namespace, row, 0, {
			virt_text = { { string.rep(" ", codeblock_padding), "Normal" } },
			virt_text_win_col = 0,
			virt_text_repeat_linebreak = true,
			priority = 1,
		})
	end
end

local render_syslang_headline_gutter = function(bufnr, force)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "syslang" then
		return
	end

	local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
	if not force and vim.b[bufnr].syslang_headline_render_changedtick == changedtick then
		return
	end

	pcall(vim.treesitter.start, bufnr, "syslang")
	vim.api.nvim_buf_clear_namespace(bufnr, syslang_render_namespace, 0, -1)

	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "syslang")
	if not ok or not parser then
		vim.b[bufnr].syslang_headline_gutter_rows = {}
		vim.b[bufnr].syslang_headline_render_changedtick = changedtick
		vim.cmd("redrawstatus")
		return
	end

	local trees = parser:parse()
	local tree = trees and trees[1]
	if not tree then
		vim.b[bufnr].syslang_headline_gutter_rows = {}
		vim.b[bufnr].syslang_headline_render_changedtick = changedtick
		vim.cmd("redrawstatus")
		return
	end
	local query = get_syslang_headline_query()
	if not query then
		vim.b[bufnr].syslang_headline_gutter_rows = {}
		vim.b[bufnr].syslang_headline_render_changedtick = changedtick
		vim.cmd("redrawstatus")
		return
	end

	local headlines = require("headlines")
	local rows = {}
	local width = vim.api.nvim_win_get_width(0)
	local left_offset = vim.fn.winsaveview().leftcol

	for _, match in query:iter_matches(tree:root(), bufnr) do
		for id, node in pairs(match) do
			local capture = query.captures[id]
			if capture == "headline" then
				local headline_node = get_query_match_node(node)
				if not headline_node then
					goto continue
				end

				local headline_text = vim.trim(vim.treesitter.get_node_text(headline_node, bufnr))
				if headline_text == "" then
					goto continue
				end

				local level = #headline_text
				local index = math.min(level, #syslang_headline_highlights)
				local hl_group = syslang_headline_highlights[index]
				local margin_hl_group = "SyslangHeadlineMargin" .. index
				local start_row = headline_node:range()
				local reverse_hl_group = headlines.make_reverse_highlight(hl_group)

				set_syslang_headline_gutter_row(bufnr, rows, start_row, " ", hl_group, " ", margin_hl_group)

				if shared_config.fat_headlines then
					if start_row > 0 then
						local upper_row = start_row - 1
						if is_blank_line(bufnr, upper_row) and not is_shared_heading_gap(bufnr, upper_row) then
							set_syslang_headline_gutter_row(
								bufnr,
								rows,
								upper_row,
								shared_config.fat_headline_upper_string,
								reverse_hl_group,
								shared_config.fat_headline_upper_string,
								reverse_hl_group
							)
							set_syslang_headline_text_row(
								bufnr,
								upper_row,
								shared_config.fat_headline_upper_string:rep(width),
								reverse_hl_group
							)
						end
					end

					if is_blank_line(bufnr, start_row + 1) then
						set_syslang_headline_gutter_row(
							bufnr,
							rows,
							start_row + 1,
							shared_config.fat_headline_lower_string,
							reverse_hl_group,
							shared_config.fat_headline_lower_string,
							reverse_hl_group
						)
						set_syslang_headline_text_row(
							bufnr,
							start_row + 1,
							shared_config.fat_headline_lower_string:rep(width),
							reverse_hl_group
						)
					end
				end
			elseif capture == "codeblock" then
				local codeblock_node = get_query_match_node(node)
				if codeblock_node then
					set_syslang_codeblock(bufnr, codeblock_node, left_offset)
				end
			end
			::continue::
		end
	end

	vim.b[bufnr].syslang_headline_gutter_rows = rows
	vim.b[bufnr].syslang_headline_render_changedtick = changedtick
	vim.cmd("redrawstatus")
end

local request_syslang_headline_render = function(bufnr, debounce_ms)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "syslang" then
		return
	end
	if vim.b[bufnr].syslang_headline_render_changedtick == vim.api.nvim_buf_get_changedtick(bufnr) then
		return
	end

	local generation = (vim.b[bufnr].syslang_headline_render_generation or 0) + 1
	vim.b[bufnr].syslang_headline_render_generation = generation
	vim.b[bufnr].syslang_headline_render_scheduled = true
	vim.defer_fn(function()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		if vim.b[bufnr].syslang_headline_render_generation ~= generation then
			return
		end

		vim.b[bufnr].syslang_headline_render_scheduled = nil
		render_syslang_headline_gutter(bufnr, false)
	end, debounce_ms)
end

local render_syslang_headline_gutter_now = function(bufnr, force)
	if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "syslang" then
		vim.b[bufnr].syslang_headline_render_generation =
			(vim.b[bufnr].syslang_headline_render_generation or 0) + 1
		vim.b[bufnr].syslang_headline_render_scheduled = nil
	end

	render_syslang_headline_gutter(bufnr, force)
end

local attach_syslang_headline_gutter = function(bufnr)
	if vim.b[bufnr].syslang_headline_gutter_attached then
		render_syslang_headline_gutter_now(bufnr, true)
		return
	end

	vim.b[bufnr].syslang_headline_gutter_attached = true

	vim.api.nvim_create_autocmd("BufEnter", {
		group = syslang_headline_group,
		buffer = bufnr,
		callback = function()
			render_syslang_headline_gutter_now(bufnr, true)
		end,
	})

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = syslang_headline_group,
		buffer = bufnr,
		callback = function()
			render_syslang_headline_gutter_now(bufnr, false)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = syslang_headline_group,
		buffer = bufnr,
		callback = function(args)
			local debounce_ms = args.event == "TextChangedI" and SYSLANG_HEADLINE_RENDER_DEBOUNCE_MS or 0
			request_syslang_headline_render(bufnr, debounce_ms)
		end,
	})

	render_syslang_headline_gutter_now(bufnr, true)
end

return lib.module.create({
	name = "headlines",
	-- enabled = false,
	hosts = "*",
	plugins = {
		{
			"lukas-reineke/headlines.nvim",
			ft = {
				"syslang",
				-- "markdown",
			},
			dependencies = { "nvim-treesitter/nvim-treesitter" },
			config = function()
				local headlines = require("headlines")
				local query = get_syslang_headline_query()
				if not query then
					return
				end

				headlines.setup({
					-- markdown = shared.config,
					markdown = { query = false },
					rmd = { query = false },
					norg = { query = false },
					org = { query = false },
					syslang = vim.tbl_extend("force", shared_config, {
						fat_headlines = false,
						headline_highlights = syslang_headline_highlights,
						bullet_highlights = {},
						codeblock_highlight = false,
						query = query,
					}),
				})

				local bufnr = vim.api.nvim_get_current_buf()
				if vim.bo[bufnr].filetype == "syslang" then
					attach_syslang_headline_gutter(bufnr)
				end

				vim.api.nvim_create_autocmd("FileType", {
					group = syslang_headline_group,
					pattern = "syslang",
					callback = function(args)
						attach_syslang_headline_gutter(args.buf)
					end,
				})
			end,
		},
	},
})
