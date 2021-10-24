local M = {}

function M.restart_lsp()
    vim.cmd ':LspRestart'
end

function M.ensure_dir(path_to_create)
    path_to_create = vim.fn.expand(path_to_create)
    if not vim.loop.fs_access(path_to_create, "r") then
        local success = vim.fn.mkdir(path_to_create, 'p')
        if not success then
            vim.api.nvim_err_writeln('Could not create folder '..path_to_create..' E: '..tostring(success))
        end
    end
    return path_to_create
end


function M.join(list, sep)
    local str = ''
    local first = true
    for _, s in ipairs(list) do
        if first then
            str = str .. s
            first = false
        else
            str = str .. sep .. s
        end
    end
    return str
end

function M.is_in_list(list, value)
    for _, v in pairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

function M.split_newlines(text)
    local lines = {}
    for s in text:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end
    return lines
end

function M.keys(table)
    local list = {}
    for key, _ in pairs(table) do
        list[#list+1] = key
    end
    return list
end

function M.read_only (t)
    local proxy = {}
    local mt = {       -- create metatable
        __index = t,
        __newindex = function (t,k,v)
            error("attempt to update a read-only table", 2)
        end
    }
    setmetatable(proxy, mt)
    return proxy
end

function M.prompt_selection(select_list)
    local promptlist = {}
    for i, name in ipairs(select_list) do
        promptlist[i] = i .. ': ' .. name
    end

    local selected = nil
    vim.fn.inputsave()
    local inp = vim.fn.inputlist(promptlist)
    vim.fn.inputrestore()
    if inp > 0 then
        selected = select_list[inp]
    end

    return selected
end

return M
