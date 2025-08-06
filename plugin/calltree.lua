vim.api.nvim_create_user_command('CallTree', function(opts)
    local direction = "outgoing"
    
    if opts.args and opts.args ~= "" then
        if opts.args == "in" or opts.args == "incoming" then
            direction = "incoming"
        elseif opts.args == "out" or opts.args == "outgoing" then  
            direction = "outgoing"
        else
            vim.notify("Invalid direction: " .. opts.args .. ". Use 'in' or 'out'", vim.log.levels.ERROR)
            return
        end
    end
    
    require('calltree').show_call_tree({ direction = direction })
end, {
    nargs = '?',
    desc = 'Show call tree for function under cursor',
    complete = function()
        return { 'in', 'incoming', 'out', 'outgoing' }
    end
})

vim.api.nvim_create_user_command('CallTreeIncoming', function()
    require('calltree').show_call_tree({ direction = "incoming" })
end, {
    desc = 'Show incoming calls (callers)'
})

vim.api.nvim_create_user_command('CallTreeOutgoing', function()
    require('calltree').show_call_tree({ direction = "outgoing" })
end, {
    desc = 'Show outgoing calls (callees)'
})

vim.api.nvim_create_user_command('CallTreeSetup', function()
    local config = {
        max_depth = 3,
        direction = "outgoing",
        async = true,
        window = {
            width = 60,
            height = 20,
            border = "rounded"
        }
    }
    
    local config_str = vim.inspect(config)
    vim.notify("Add this to your config:\n\nrequire('calltree').setup(" .. config_str .. ")", vim.log.levels.INFO)
end, {
    desc = 'Show setup configuration example'
})

vim.api.nvim_create_user_command('CallTreeDebug', function()
    vim.g.calltree_debug = not vim.g.calltree_debug
    vim.notify("CallTree debug mode: " .. (vim.g.calltree_debug and "ON" or "OFF"), vim.log.levels.INFO)
end, {
    desc = 'Toggle debug mode for CallTree'
})