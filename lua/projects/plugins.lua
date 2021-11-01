local utils = require 'projects.utils'

-- ****************************************************************************
-- Plugins
--
-- local Plugin = {
--     name = 'something unique'
--     on_init = function(host) ..
--     on_load = function(project) ..
--     on_close = function(project) ..
-- }
--
-- They are stored in a list, to ensure ordering, first come first served.
-- ****************************************************************************

local M = {
    _plugins = {},
}

-- Returns the plugins as a table keyed on name.
-- The order is assigned as attribute _prj_id for introspection.
function M.plugins()
    local ret = {}
    for i, plugin in ipairs(M._plugins) do
        ret[plugin.name] = plugin
        ret[plugin.name]._prj_id = i
    end
    return ret
end

function M.register_plugin(plugin, host)
    if utils.empty(plugin.name) then
        print 'project plugin must have a name!'
        return
    end

    local plugs = M.plugins()
    if plugs[plugin.name] then
        print('project plugin with name ' .. plugin.name .. ' already exists !')
        return
    end

    table.insert(M._plugins, plugin) -- utils.deepcopy(plugin))

    if plugin.on_init then
        plugin.on_init(host)
    end
end

function M.publish_event(method, ...)
    for _, plugin in ipairs(M._plugins) do
        if plugin[method] then
            plugin[method](...)
        end
    end
end

function M.init()
    M._plugins = {}
end

return M
