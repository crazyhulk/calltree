local gopls = require('calltree.gopls')

local M = {}

-- 缓存模块信息以提高性能
local module_cache = {}

-- 查找 go.mod 文件并获取模块名
local function get_module_name(start_path)
	if module_cache[start_path] then
		return module_cache[start_path]
	end

	local current_path = start_path
	while current_path and current_path ~= "/" do
		local go_mod_path = current_path .. "/go.mod"
		local file = io.open(go_mod_path, "r")
		if file then
			local content = file:read("*all")
			file:close()
			local module_name = content:match("module%s+([%w%.-_/]+)")
			if module_name then
				module_cache[start_path] = module_name
				return module_name
			end
		end
		local parent = vim.fn.fnamemodify(current_path, ":h")
		if parent == current_path then break end
		current_path = parent
	end

	module_cache[start_path] = nil
	return nil
end

-- 判断是否为项目外部函数（标准库或第三方库）
local function is_external_function(item)
	if not item or not item.uri then
		return true -- 默认认为是外部的
	end

	if not item.detail then
		return true
	end

	local pkg_path = item.detail:match("^([^•]+)")
	if not pkg_path then
		return true
	end

	pkg_path = pkg_path:gsub("^%s+", ""):gsub("%s+$", "")
	local cwd = vim.fn.getcwd()
	local module_name = get_module_name(cwd)

	if module_name and pkg_path:sub(1, #module_name) == module_name then
		return false -- 项目内函数
	end

	return true -- 外部函数
end

function M.new(gopls_client)
	local obj = {
		client = gopls_client
	}
	setmetatable(obj, { __index = M })
	return obj
end

function M:get_item_key(item)
	return string.format("%s:%s:%d:%d", 
		item.uri, item.name, 
		item.range.start.line, item.range.start.character)
end

function M:build(position, direction, max_depth, exclude_stdlib)
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

	self:build_recursive(tree, direction, max_depth, exclude_stdlib)
	return tree
end

function M:build_recursive(node, direction, max_depth, exclude_stdlib)
	if node.level >= max_depth then
		return
	end

	-- 防止循环引用 - 检查是否在当前调用路径中
	local item_key = self:get_item_key(node.item)

	-- 检查当前路径是否存在循环
	local current = node.parent
	while current do
		if self:get_item_key(current.item) == item_key then
			node.is_recursive = true
			return
		end
		current = current.parent
	end

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

	-- 按照调用在源代码中的位置排序
	-- 为每个调用的每个范围创建单独的条目
	local sortedCalls = {}
	for _, call in ipairs(calls) do
		if call.ranges and #call.ranges > 0 then
			for _, range in ipairs(call.ranges) do
				table.insert(sortedCalls, {
					type = call.type,
					item = call.item,
					range = range
				})
			end
		else
			-- 如果没有范围信息，直接添加
			table.insert(sortedCalls, {
				type = call.type,
				item = call.item,
				range = nil
			})
		end
	end

	-- 按行号和列号排序
	table.sort(sortedCalls, function(a, b)
		if a.range and b.range then
			if a.range.start.line == b.range.start.line then
				return a.range.start.character < b.range.start.character
			end
			return a.range.start.line < b.range.start.line
		end
		return false
	end)

	for _, call in ipairs(sortedCalls) do
		local child = {
			item = call.item,
			children = {},
			level = node.level + 1,
			call_type = call.type,
			ranges = call.range and {call.range} or nil,
			parent = node
		}

		table.insert(node.children, child)

		-- 如果启用了外部库排除，且子节点是外部函数，则不进行递归
		if exclude_stdlib and is_external_function(child.item) then
			-- 不进行递归，但仍然添加到树中显示
		else
			self:build_recursive(child, direction, max_depth, exclude_stdlib)
		end
	end
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
