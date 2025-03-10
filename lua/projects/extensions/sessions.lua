local uv = vim.uv or vim.loop

local M = {}

---Load a session
---@param session_path? string
---@return boolean
function M.load(session_path)
    if session_path and vim.fn.filereadable(session_path) ~= 0 then
        print('Loading session: ' .. session_path)
        vim.cmd('source ' .. session_path)
        M.start()
        return true
    end
    print('Session not found: ' .. session_path)
    return false
end

---Start automatic recording
---@param session_path? string
---@return nil
function M.start(session_path)
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = vim.api.nvim_create_augroup('projects_sessions', { clear = true }),
        callback = function()
            M.save(session_path)
        end,
    })
end

---Save the session
---@param session_path? string
---@return nil
function M.save(session_path)
    print('Saving session: ' .. session_path)
    vim.cmd('mks! ' .. session_path)
end

---Delete a session
---@param session_path? string
---@return nil
function M.delete(session_path)
    if session_path and uv.fs_stat(session_path) ~= 0 then
        print('Deleting session: ' .. session_path)
        vim.schedule(function()
            M.stop()
            vim.fn.delete(vim.fn.expand(session_path))
        end)
    end
end

---Stop automatic recording
---@return nil
function M.stop()
    print 'Stopping session'
    pcall(vim.api.nvim_del_augroup_by_name, 'projects_sessions')
end

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local sessions = {
    name = 'sessions',
    _ext_priority = 10000, -- we want to be last
    current_session_path = '',
}

function sessions.project_extension_init(host)
    sessions.host = host
end

local function session_path(project)
    local session_name = project:ext_config('sessions', {}).session_name or project.unique_name
    local session_dir = require('projects').projects_startify_session_dir()
    return vim.fn.expand(session_dir) .. session_name
end

function sessions.on_project_open(project)
    sessions.current_session_path = session_path(project)

    local existed = M.load(sessions.current_session_path)
    if not existed then
        M.save(sessions.current_session_path)
        M.start()
    end

    -- Because the session can possibly cd to a different directory
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")
end

function sessions.on_project_close()
    if sessions.current_session_path ~= '' then
        M.save(sessions.current_session_path)
    end
    M.stop()
    sessions.current_session_path = ''
end

function sessions.on_project_delete(project)
    if sessions.host then
        local session_name = project:ext_config('sessions', {}).session_name or project.name
        if sessions.host.prompt_yes_no('Delete associated session: ' .. session_name) then
            local session = session_path(project)
            M.delete(session)
        end
    end
end

function sessions.config_example()
    return [[
]]
end

return sessions
