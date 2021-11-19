local utils = require 'projects.utils'

-- ****************************************************************************
-- Persistent state using JSON
-- ****************************************************************************
local function json_decode(data)
    local ok, result = pcall(vim.fn.json_decode, data)
    if ok then
        return result
    else
        return nil
    end
end

local function json_encode(data)
    local ok, result = pcall(vim.fn.json_encode, data)
    if ok then
        return result
    else
        return nil
    end
end

local function load_json(path)
    path = vim.fn.expand(path)
    if vim.fn.filereadable(path) == 0 then
        -- print('cannot read file: ' .. path )
        return nil
    end

    return json_decode(vim.fn.readfile(path))
end

local function save_json(path, table)
    local json_string = json_encode(table)

    path = vim.fn.expand(path)
    local path_stem = vim.fn.fnamemodify(path, ':h')
    -- print('stem ' .. tostring(path_stem))
    utils.ensure_dir(tostring(path_stem))
    if vim.fn.writefile({ json_string }, path) ~= 0 then
        return false
    end
    return true
end

-- ****************************************************************************
--
-- ****************************************************************************
local Persistent = {}
Persistent.__index = Persistent

function Persistent:create(path)
    local new = {} -- our new object
    setmetatable(new, self) -- make Persistent handle lookup

    new.state = {}
    new.loaded = false
    new.path = vim.fn.expand(path)

    return new
end

function Persistent:try_load()
    if self.path then
        self.state = load_json(self.path) or {}
        self.loaded = true
    end
end

function Persistent:try_save()
    if vim.fn.filereadable(self.path) == 0 then
        -- print('file does not exist: ' .. path )
    else
        if not self.loaded then
            local state_before = self.state
            self:try_load()
            for key, value in pairs(state_before) do
                self.state[key] = value
            end
        end
    end

    if self.path then
        save_json(self.path, self.state)
    end
end

function Persistent:get(key, default)
    if not self.loaded then
        self:try_load()
    end
    return self.state[key] or default
end

function Persistent:set(key, value)
    -- print('p.set '..key..':'..value)
    local before = self.state[key]
    if value ~= before then
        self.state[key] = value
        self:try_save()
    end
end

return Persistent
