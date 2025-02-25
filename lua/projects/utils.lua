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

function M.table_merge(base, other, level)
    local next_level = level

    if next_level then
        next_level = next_level - 1
    end

    local do_next = next_level == nil or next_level > 0

    for k, v in pairs(other) do
        if do_next and type(v) == 'table' then
            if type(base[k] or false) == 'table' then
                M.table_merge(base[k] or {}, other[k] or {}, next_level)
            else
                base[k] = v
            end
        else
            base[k] = v
        end
    end
    return base
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

-- https://stackoverflow.com/questions/19326368/iterate-over-lines-including-blank-lines
function M.lines(s)
    if s:sub(-1) ~= '\n' then
        s = s .. '\n'
    end
    return s:gmatch '(.-)\n'
end

function M.table_get(table, selectors, default)
    cursor = table
    for _, selector in ipairs(selectors) do
        if type(cursor) == 'table' then
            cursor = cursor[selector]
        else
            -- we have an unresolved selector so we bail out.
            cursor = nil
            break
        end
    end

    return cursor or default
end

function M.table_compare(o1, o2, ignore_mt)
    if o1 == o2 then
        return true
    end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then
        return false
    end
    if o1Type ~= 'table' then
        return false
    end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or M.table_compare(value1, value2, ignore_mt) == false then
            -- print('not eq: ' .. tostring(value1) .. ' '.. tostring(value2))
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then
            -- print('missing key')
            return false
        end
    end
    return true
end

function M.assert_table_equal(result, expected)
    local _, eq = pcall(M.table_compare, result, expected, true)
    if eq == true then
        assert.is_true(eq)
    else
        print(' equal "' .. tostring(eq) .. '"')
        assert.is_equal(expected, result)
    end
end

function M.is_win()
    return package.config:sub(1, 1) == '\\'
end

function M.get_path_separator()
    if M.is_win() then
        return '\\'
    end
    return '/'
end

function M.script_path()
    local str = debug.getinfo(2, 'S').source:sub(2)
    if M.is_win() then
        str = str:gsub('/', '\\')
    end
    return str:match('(.*' .. M.get_path_separator() .. ')')
end

function M.local_project_path(script_path)
    -- print('script_path: ' .. script_path)
    local mypath = vim.fn.fnamemodify(vim.fn.fnamemodify(script_path, ':h'), ':h')
    return mypath
end

return M
