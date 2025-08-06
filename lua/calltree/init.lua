local M = {}

local gopls = require('calltree.gopls')
local builder = require('calltree.builder')
local ui = require('calltree.ui')

M.config = {
    max_depth = 3,
    direction = "outgoing", -- "incoming", "outgoing"
    async = false, -- 暂时用同步测试
    auto_close = true,
    window = {
        width = 60,
        height = 20,
        border = "rounded"
    }
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.show_call_tree(opts)
    opts = vim.tbl_deep_extend("force", M.config, opts or {})
    
    local position = vim.lsp.util.make_position_params().position
    local gopls_client = gopls.new()
    
    if not gopls_client then
        vim.notify("gopls not available", vim.log.levels.ERROR)
        return
    end
    
    local call_builder = builder.new(gopls_client)
    
    -- Debug: check if methods exist
    if not call_builder.build_async then
        vim.notify("build_async method not found", vim.log.levels.ERROR)
        return
    end
    
    -- Enable debug mode temporarily if needed
    -- vim.g.calltree_debug = true
    
    if opts.async then
        call_builder:build_async(position, opts.direction, opts.max_depth, function(tree)
            if tree and tree.children and #tree.children > 0 then
                ui.show(tree, opts.window)
            elseif tree then
                -- Tree exists but has no children
                vim.notify("Function '" .. tree.item.name .. "' has no " .. 
                    (opts.direction == "incoming" and "callers" or "callees"), vim.log.levels.INFO)
            else
                vim.notify("No call hierarchy found - make sure cursor is on a function name", vim.log.levels.WARN)
            end
        end)
    else
        local tree = call_builder:build(position, opts.direction, opts.max_depth)
        if tree and tree.children and #tree.children > 0 then
            ui.show(tree, opts.window)
        elseif tree then
            -- Tree exists but has no children
            vim.notify("Function '" .. tree.item.name .. "' has no " .. 
                (opts.direction == "incoming" and "callers" or "callees"), vim.log.levels.INFO)
        else
            vim.notify("No call hierarchy found - make sure cursor is on a function name", vim.log.levels.WARN)
        end
    end
end

return M