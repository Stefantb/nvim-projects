local utils = require 'projects.utils'

-- ****************************************************************************
--
-- ****************************************************************************
local function close()
    print('Closing current session')
    vim.cmd "execute 'SClose'"
end

local function load(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SLoad " .. session_name .. "'")
    end
end

local function exists(session_name)
    if session_name and session_name ~= '' then
        local list = vim.fn['startify#session_list'] ''
        return utils.is_in_list(list, session_name)
    end
    return false
end

local function save(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SSave " .. session_name .. "'")
    end
end

local function delete(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SDelete " .. session_name .. "'")
    end
end

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local sessions = {
    name = 'sessions',
    _ext_priority = 10000, -- we want to be last
    -- current_session_name = '',
}

function sessions.project_extension_init(host)
    sessions.host = host
end

function sessions.on_project_open(project)
    close()

    local session_name = project:ext_config('sessions', {}).session_name or project.unique_name

    if session_name then
        if exists(session_name) then
            load(session_name)
        else
            save(session_name)
        end
    end
    -- Because the session can possibly cd to a different directory
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")
end

function sessions.on_project_close()
    close()
    -- sessions.current_session_name = ''
end

function sessions.on_project_delete(project)
    if sessions.host then
        local session_name = project:ext_config('sessions', {}).session_name or project.name
        if sessions.host.prompt_yes_no('Delete associated session: ' .. session_name) then
            delete(session_name)
        end
    end
end

function sessions.config_example()
    return [[
]]
end

return sessions
