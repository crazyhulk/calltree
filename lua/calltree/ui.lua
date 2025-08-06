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
    local height = math.min(window_opts.height or 20, #lines + 2)
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local content = {}
    local line_data = {}
    
    for i, line_info in ipairs(lines) do
        table.insert(content, line_info.text)
        line_data[i] = line_info
    end
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
    local win_config = {
        relative = 'cursor',
        width = width,
        height = height,
        col = 1,
        row = 1,
        anchor = 'NW',
        style = 'minimal',
        border = window_opts.border or 'rounded',
        title = ' Call Tree ',
        title_pos = 'center'
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_config)
    
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'wrap', false)
    
    local function jump_to_definition()
        local current_line = vim.api.nvim_win_get_cursor(win)[1]
        local line_info = line_data[current_line]
        
        if line_info and line_info.item then
            local uri = line_info.item.uri
            local range = line_info.item.range
            
            vim.api.nvim_win_close(win, true)
            
            local file_path = vim.uri_to_fname(uri)
            vim.cmd('edit ' .. file_path)
            
            local line_num = range.start.line + 1
            local col_num = range.start.character
            vim.api.nvim_win_set_cursor(0, {line_num, col_num})
            
            vim.cmd('normal! zz')
        end
    end
    
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
    
    local keymap_opts = { buffer = buf, silent = true, nowait = true }
    
    vim.keymap.set('n', '<CR>', jump_to_definition, keymap_opts)
    vim.keymap.set('n', '<2-LeftMouse>', jump_to_definition, keymap_opts)
    vim.keymap.set('n', 'q', close_window, keymap_opts)
    vim.keymap.set('n', '<Esc>', close_window, keymap_opts)
    
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = buf,
        callback = function()
            close_window()
        end,
        once = true
    })
    
    vim.api.nvim_buf_set_keymap(buf, 'n', '?', '', {
        callback = function()
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
            
            local help_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
            vim.api.nvim_buf_set_option(help_buf, 'modifiable', false)
            
            local help_win = vim.api.nvim_open_win(help_buf, true, {
                relative = 'cursor',
                width = 50,
                height = #help_lines,
                col = 0,
                row = 0,
                style = 'minimal',
                border = 'rounded',
                title = ' Help ',
                title_pos = 'center'
            })
            
            vim.keymap.set('n', 'q', function()
                vim.api.nvim_win_close(help_win, true)
            end, { buffer = help_buf })
        end,
        silent = true
    })
end

return M