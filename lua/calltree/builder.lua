local gopls = require('calltree.gopls')

local M = {}

function M.new(gopls_client)
    local obj = {
        client = gopls_client,
        visited = {}
    }
    setmetatable(obj, { __index = M })
    return obj
end

function M:get_item_key(item)
    return string.format("%s:%s:%d:%d", 
        item.uri, item.name, 
        item.range.start.line, item.range.start.character)
end

function M:build(position, direction, max_depth)
    local root_item = gopls.prepare_call_hierarchy(self.client, position)
    if not root_item then
        return nil
    end
    
    local tree = {
        item = root_item,
        children = {},
        level = 0,
        direction = direction
    }
    
    self.visited = {}
    self:build_recursive(tree, direction, max_depth)
    return tree
end

function M:build_recursive(node, direction, max_depth)
    if node.level >= max_depth then
        return
    end
    
    local item_key = self:get_item_key(node.item)
    if self.visited[item_key] then
        node.is_recursive = true
        return
    end
    
    self.visited[item_key] = true
    
    local calls = {}
    
    if direction == "incoming" then
        local incoming = gopls.get_incoming_calls(self.client, node.item)
        for _, call in ipairs(incoming) do
            table.insert(calls, {
                type = "caller",
                item = call.from,
                ranges = call.fromRanges
            })
        end
    elseif direction == "outgoing" then
        local outgoing = gopls.get_outgoing_calls(self.client, node.item)
        for _, call in ipairs(outgoing) do
            table.insert(calls, {
                type = "callee",
                item = call.to,
                ranges = call.fromRanges
            })
        end
    end
    
    for _, call in ipairs(calls) do
        local child = {
            item = call.item,
            children = {},
            level = node.level + 1,
            call_type = call.type,
            ranges = call.ranges,
            parent = node
        }
        
        table.insert(node.children, child)
        self:build_recursive(child, direction, max_depth)
    end
    
    self.visited[item_key] = nil
end

function M:build_async(position, direction, max_depth, callback)
    local root_item = gopls.prepare_call_hierarchy(self.client, position)
    if not root_item then
        callback(nil)
        return
    end
    
    local tree = {
        item = root_item,
        children = {},
        level = 0,
        direction = direction
    }
    
    self.visited = {}
    
    local function build_async_recursive(node, depth, cb)
        if depth >= max_depth then
            cb()
            return
        end
        
        local item_key = self:get_item_key(node.item)
        if self.visited[item_key] then
            node.is_recursive = true
            cb()
            return
        end
        
        self.visited[item_key] = true
        
        local pending_requests = 0
        local completed_requests = 0
        
        local function check_completion()
            completed_requests = completed_requests + 1
            if completed_requests >= pending_requests then
                local pending_children = #node.children
                if pending_children == 0 then
                    self.visited[item_key] = nil
                    cb()
                    return
                end
                
                for _, child in ipairs(node.children) do
                    build_async_recursive(child, depth + 1, function()
                        pending_children = pending_children - 1
                        if pending_children == 0 then
                            self.visited[item_key] = nil
                            cb()
                        end
                    end)
                end
            end
        end
        
        if direction == "incoming" or direction == "both" then
            pending_requests = pending_requests + 1
            gopls.get_incoming_calls_async(self.client, node.item, function(incoming)
                for _, call in ipairs(incoming) do
                    local child = {
                        item = call.from,
                        children = {},
                        level = depth + 1,
                        call_type = "caller",
                        ranges = call.fromRanges,
                        parent = node
                    }
                    table.insert(node.children, child)
                end
                check_completion()
            end)
        end
        
        if direction == "outgoing" or direction == "both" then
            pending_requests = pending_requests + 1
            gopls.get_outgoing_calls_async(self.client, node.item, function(outgoing)
                for _, call in ipairs(outgoing) do
                    local child = {
                        item = call.to,
                        children = {},
                        level = depth + 1,
                        call_type = "callee", 
                        ranges = call.fromRanges,
                        parent = node
                    }
                    table.insert(node.children, child)
                end
                check_completion()
            end)
        end
        
        if pending_requests == 0 then
            self.visited[item_key] = nil
            cb()
        end
    end
    
    build_async_recursive(tree, 0, function()
        callback(tree)
    end)
end

return M