local utils = require 'projects.utils'

-- ****************************************************************************
--
-- ****************************************************************************
local function close()
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
--
-- ****************************************************************************
local sessions = {
    name = 'sessions',
    _plug_priority = 99,
}

function sessions.project_plugin_init(host)
    sessions.host = host
end

function sessions.on_project_open(project)
    close()
    if project.session_name then
        if exists(project.session_name) then
            load(project.session_name)
        else
            save(project.session_name)
        end
    end
    -- Because the session can possibly cd to a different directory
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")
end

function sessions.on_project_close()
    close()
end

function sessions.on_project_delete(project)
    if sessions.host then
        if sessions.host.prompt_yes_no('Delete associated session: ' .. project.session_name) then
            delete(project.session_name)
        end
    end
end

return sessions

