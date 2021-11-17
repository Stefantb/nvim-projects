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
    _ext_priority = 10000, -- we want to be last
}

function sessions.project_extension_init(host)
    sessions.host = host
end

function sessions.on_project_open(project)
    close()

    local default_cfg = {
        sessions = {
            session_name = project.name
        }
    }

    -- update the project
    project.extensions = utils.table_merge(project.extensions, default_cfg)

    local psn = project:get_sub('sessions', 'session_name', project.name )
    if psn then
        if exists(psn) then
            load(psn)
        else
            save(psn)
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
        local psn = project:get_sub('sessions', 'session_name', project.name )
        if sessions.host.prompt_yes_no('Delete associated session: ' .. psn) then
            delete(psn)
        end
    end
end

sessions.config_example = [[
'sessions' = {
    -- session_name = 'defaults to project name',
},
]]

return sessions

