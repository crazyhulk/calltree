local popup = require "plenary.popup"

local M = {}

local function get_file_name(uri)
	local path = vim.uri_to_fname(uri)
	return vim.fn.fnamemodify(path, ":t")
end

local function get_display_name(item)
	local file_name = get_file_name(item.uri)
	return string.format("%s (%s:%d)", item.name, file_name, item.range.start.line + 1)
end

local function render_tree(tree, lines, level, prefix, is_last)
	level = level or 0
	prefix = prefix or ""

	local indent = level == 0 and "" or prefix
	local connector = level == 0 and "" or (is_last and "└─ " or "├─ ")
	local icon = ""

	if tree.call_type == "caller" then
		icon = "📞 "
	elseif tree.call_type == "callee" then
		icon = "📤 "
	else
		icon = "🎯 "
	end

	local display_name = get_display_name(tree.item)
	if tree.is_recursive then
		display_name = display_name .. " (recursive)"
	end

	local line = indent .. connector .. icon .. display_name
	table.insert(lines, {
		text = line,
		item = tree.item,
		level = level,
		ranges = tree.ranges
	})

	for i, child in ipairs(tree.children) do
		local child_prefix = level == 0 and "" or prefix .. (is_last and "    " or "│   ")
		local child_is_last = i == #tree.children
		render_tree(child, lines, level + 1, child_prefix, child_is_last)
	end
end

function M.show(tree, window_opts)
	window_opts = window_opts or {}

	local lines = {}
	render_tree(tree, lines)

	if #lines == 0 then
		vim.notify("No call hierarchy found", vim.log.levels.WARN)
		return
	end

	local width = window_opts.width or 60
	local height = math.min(window_opts.height or 20, #lines)

	-- 准备显示内容
	local content = {}
	local line_data = {}

	for i, line_info in ipairs(lines) do
		table.insert(content, line_info.text)
		line_data[i] = line_info
	end

	-- 计算居中位置和大小，类似 Telescope 的布局
	local screen_width = vim.o.columns
	local screen_height = vim.o.lines

	-- 留出上下左右的空间，类似 Telescope
	local margin_horizontal = math.floor(screen_width * 0.1)  -- 左右各留10%
	local margin_vertical = math.floor(screen_height * 0.1)   -- 上下各留10%

	local popup_width = math.min(width, screen_width - 2 * margin_horizontal)
	local popup_height = math.min(height, screen_height - 2 * margin_vertical)

	-- 居中计算
	local popup_col = math.floor((screen_width - popup_width) / 2)
	local popup_line = math.floor((screen_height - popup_height) / 2)

	-- 使用 plenary.popup 创建窗口
	local win_id, popup_opts = popup.create(content, {
		title = "Call Tree",
		highlight = "TelescopeNormal",
		line = popup_line,
		col = popup_col,
		minwidth = popup_width,
		minheight = popup_height,
		maxwidth = popup_width,
		maxheight = popup_height,
		borderchars = window_opts.border == 'single' and 
			{ "─", "│", "─", "│", "┌", "┐", "┘", "└" } or
			{ "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		finalize_callback = function(popup_win, popup_buf)
			-- 设置窗口选项
			vim.api.nvim_win_set_option(popup_win, 'cursorline', true)
			vim.api.nvim_win_set_option(popup_win, 'wrap', false)
			vim.api.nvim_buf_set_option(popup_buf, 'modifiable', false)
			vim.api.nvim_buf_set_option(popup_buf, 'bufhidden', 'wipe')

			-- 跳转到定义的函数
			local function jump_to_definition()
				local current_line = vim.api.nvim_win_get_cursor(popup_win)[1]
				local line_info = line_data[current_line]

				if line_info and line_info.item then
					local uri = line_info.item.uri
					local range = line_info.item.range

					-- 关闭 popup 窗口
					if vim.api.nvim_win_is_valid(popup_win) then
						vim.api.nvim_win_close(popup_win, true)
					end

					local file_path = vim.uri_to_fname(uri)
					vim.cmd('edit ' .. file_path)

					local line_num = range.start.line + 1
					local col_num = range.start.character
					vim.api.nvim_win_set_cursor(0, {line_num, col_num})

					vim.cmd('normal! zz')
				end
			end

			-- 关闭窗口的函数
			local function close_window()
				if vim.api.nvim_win_is_valid(popup_win) then
					vim.api.nvim_win_close(popup_win, true)
				end
			end

			-- 设置按键映射
			local keymap_opts = { buffer = popup_buf, silent = true, nowait = true }

			vim.keymap.set('n', '<CR>', jump_to_definition, keymap_opts)
			vim.keymap.set('n', '<2-LeftMouse>', jump_to_definition, keymap_opts)
			vim.keymap.set('n', 'q', close_window, keymap_opts)
			vim.keymap.set('n', '<Esc>', close_window, keymap_opts)

			-- 帮助功能
			vim.keymap.set('n', '?', function()
				show_help()
			end, keymap_opts)

			-- 自动关闭
			vim.api.nvim_create_autocmd({"WinLeave", "BufLeave"}, {
				buffer = popup_buf,
				callback = function()
					close_window()
				end,
				once = true
			})
		end
	})
end

-- 显示帮助窗口
local function show_help()
	local help_lines = {
		"Call Tree Help:",
		"",
		"Navigation:",
		"  <CR>          - Jump to function definition", 
		"  <2-LeftMouse> - Jump to function definition",
		"  q / <Esc>     - Close window",
		"",
		"Symbols:",
		"  🎯 - Root function",
		"  📞 - Caller (who calls this)",
		"  📤 - Callee (called by this)",
	}

	-- 计算居中位置
	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local help_width = 50
	local help_height = #help_lines

	local help_col = math.floor((screen_width - help_width) / 2)
	local help_line = math.floor((screen_height - help_height) / 2)

	local help_win, help_opts = popup.create(help_lines, {
		title = "Help",
		highlight = "TelescopeNormal",
		line = help_line,
		col = help_col, 
		minwidth = help_width,
		minheight = help_height,
		borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		finalize_callback = function(win, buf)
			vim.api.nvim_buf_set_option(buf, 'modifiable', false)
			vim.keymap.set('n', 'q', function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end, { buffer = buf, silent = true })
			vim.keymap.set('n', '<Esc>', function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end, { buffer = buf, silent = true })
		end
	})
end

return M
