local M = {}

function M.new()
	local clients = vim.lsp.get_active_clients({ name = "gopls" })
	if #clients == 0 then
		return nil
	end

	local client = clients[1]
	return {
		client_id = client.id,
		timeout = 5000
	}
end

function M.prepare_call_hierarchy(client, position)
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(),
		position = position
	}

	local result = vim.lsp.buf_request_sync(0, "textDocument/prepareCallHierarchy", params, client.timeout)

	if result and result[client.client_id] then
		local response = result[client.client_id].result
		if response and #response > 0 then
			if vim.g.calltree_debug then
				vim.notify("Found call hierarchy item: " .. response[1].name, vim.log.levels.DEBUG)
			end
			return response[1]
		end
	end

	if vim.g.calltree_debug then
		vim.notify("No call hierarchy found at position", vim.log.levels.WARN)
	end

	return nil
end

function M.get_incoming_calls(client, hierarchy_item)
	local params = {
		item = hierarchy_item
	}

	local result = vim.lsp.buf_request_sync(0, "callHierarchy/incomingCalls", params, client.timeout)

	if result and result[client.client_id] then
		return result[client.client_id].result or {}
	end

	return {}
end

function M.get_outgoing_calls(client, hierarchy_item)
	local params = {
		item = hierarchy_item
	}

	local result = vim.lsp.buf_request_sync(0, "callHierarchy/outgoingCalls", params, client.timeout)

	if result and result[client.client_id] then
		local calls = result[client.client_id].result or {}
		-- Debug: log the result
		if vim.g.calltree_debug then
			vim.notify("Outgoing calls for " .. hierarchy_item.name .. ": " .. #calls .. " results", vim.log.levels.DEBUG)
		end
		return calls
	end

	if vim.g.calltree_debug then
		vim.notify("No outgoing calls result for " .. hierarchy_item.name, vim.log.levels.WARN)
	end

	return {}
end

function M.get_incoming_calls_async(client, hierarchy_item, callback)
	local params = {
		item = hierarchy_item
	}

	vim.lsp.buf_request(0, "callHierarchy/incomingCalls", params, function(err, result)
		if err then
			callback({})
			return
		end
		callback(result or {})
	end)
end

function M.get_outgoing_calls_async(client, hierarchy_item, callback)
	local params = {
		item = hierarchy_item
	}

	vim.lsp.buf_request(0, "callHierarchy/outgoingCalls", params, function(err, result)
		if err then
			callback({})
			return
		end
		callback(result or {})
	end)
end

return M
