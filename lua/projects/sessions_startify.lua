local utils = require 'projects.utils'

-- ****************************************************************************
-- Sessions interface relying on Startify
-- ****************************************************************************
local sessions = {}

function sessions.close()
    vim.cmd "execute 'SClose'"
end

function sessions.load(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SLoad " .. session_name .. "'")
    end
end

function sessions.exists(session_name)
    if session_name and session_name ~= '' then
        local list = vim.fn['startify#session_list'] ''
        return utils.is_in_list(list, session_name)
    end
    return false
end

function sessions.save(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SSave " .. session_name .. "'")
    end
end

function sessions.delete(session_name)
    if session_name and session_name ~= '' then
        vim.cmd("execute 'SDelete " .. session_name .. "'")
    end
end

return sessions
