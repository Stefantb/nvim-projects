local utils = require 'projects.utils'

-- ****************************************************************************
-- Plugins
--
-- local Plugin = {
--     name = 'something unique'
--     project_plugin_init = function(host) ..
--     on_project_open = function(project) ..
--     on_project_close = function(project) ..
--     on_project_delete = function(project) ..
-- }
--
-- They are stored in a list, to ensure ordering, first come first served.
-- unless _plug_priority is set, lower number makes for higher priority.
-- ****************************************************************************

local M = {
    _plugins = {},
}

local function priority_sort(a, b)
    local ap = a._plug_priority or 10
    local bp = b._plug_priority or 10
    return ap < bp
end

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

    table.insert(M._plugins, plugin)
    table.sort(M._plugins, priority_sort)

    if plugin.project_plugin_init then
        plugin.project_plugin_init(host)
    end
end

function M.unregister_plugin(plugin_name)

    local index = utils.array_find(M._plugins, function(plug)
        return plug.name == plugin_name
    end)

    if not index then
        print('cannot unregister plugin: ' .. plugin_name .. ' not found')
        return
    end

    table.remove(M._plugins, index)
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
