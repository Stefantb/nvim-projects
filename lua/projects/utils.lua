local M = {}

function M.ensure_dir(path_to_create)
    path_to_create = vim.fn.expand(path_to_create)
    if not vim.loop.fs_access(path_to_create, 'r') then
        local success = vim.fn.mkdir(path_to_create, 'p')
        if not success then
            vim.api.nvim_err_writeln('Could not create folder ' .. path_to_create .. ' E: ' .. tostring(success))
        end
    end
    return path_to_create
end

function M.join(list, sep)
    local str = ''
    local first = true
    for _, s in ipairs(list) do
        if first then
            str = s
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
    for s in text:gmatch '[^\r\n]+' do
        table.insert(lines, s)
    end
    return lines
end

function M.keys(table)
    local list = {}
    for key, _ in pairs(table) do
        list[#list + 1] = key
    end
    return list
end

function M.read_only(t)
    local proxy = {}
    local mt = { -- create metatable
        __index = function(p, k)
            if t[k] and type(t[k] == 'table') then
                return M.read_only(t[k])
            end
            return t[k]
        end,
        __newindex = function(p, k, v)
            error('attempt to update a read-only table', 2)
        end,
    }
    for key, value in pairs(t) do
        mt[key] = value
    end
    setmetatable(proxy, mt)
    return proxy
end

function M.prompt_yes_no(question)
    print(question .. ' ? [y/n]')
    local answer = vim.fn.nr2char(vim.fn.getchar())
    return answer == 'y'
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

function M.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
        end
        setmetatable(copy, M.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function M.empty(string)
    return string == nil or string == ''
end

function M.merge_first_level(base, source)
    if source then
        for k, v in pairs(source) do
            base[k] = v
        end
    end

    return base
end

function M.array_find(array, predicate)
    for i, v in ipairs(array) do
        if predicate(v) then
            return i
        end
    end
    return nil
end


return M
