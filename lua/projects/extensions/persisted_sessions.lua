local utils = require 'projects.utils'
local persisted = require 'persisted'


-- local function make_fs_safe(text)
--   return text:gsub("[\\/:]+", "_")
-- end
--
-- local function current(opts)
--   opts = opts or {}
--   local config = { use_git_branch = true, save_dir = vim.fn.stdpath("data") .. "/sessions/" }
--   local name = utils.make_fs_safe(vim.fn.getcwd())
--
--   if config.use_git_branch and opts.branch ~= false then
--     local branch = M.branch()
--     if branch then
--       branch = make_fs_safe(branch)
--       name = name .. "@@" .. branch
--     end
--   end
--
--   return config.save_dir .. name .. ".vim"
-- end

-- ****************************************************************************
--
-- ****************************************************************************
local function close()
    print 'Closing current session'
    persisted.stop()
end

local function load(session_name)
    -- local session_name = persisted.current { branch = false }
    print('Loading session: ' .. session_name)
    persisted.load { session = session_name }
    persisted.start()
end

local function save(session_name)
    print('Saving current session ' .. session_name)
    persisted.save { force = true, session = session_name }
end

local function delete(session_name)
    local session_dir = require('projects').projects_startify_session_dir()
    local from_persisted = persisted.config.save_dir
    print('Deleting session: ' .. session_name)
    persisted.delete { path = session_dir .. '/' .. session_name }
end

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local sessions = {
    name = 'sessions',
    _ext_priority = 10000, -- we want to be last
    current_session_name = '',
}

function sessions.project_extension_init(host)
    sessions.host = host
end

function sessions.on_project_open(project)
    print(vim.fn.getcwd())
    local session_name = project:ext_config('sessions', {}).session_name or project.unique_name
    sessions.current_session_name = session_name
    load(session_name)

    -- Because the session can possibly cd to a different directory
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")
end

function sessions.on_project_close()
    if sessions.current_session_name ~= '' then
        save(sessions.current_session_name)
    end
    close()
    sessions.current_session_name = ''
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
