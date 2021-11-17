local utils = require 'projects.utils'

-- ****************************************************************************
-- Extensions
--
-- local Extension = {
--     name = 'something unique'
--     project_extension_init = function(host) ..
--     on_project_open = function(project) ..
--     on_project_close = function(project) ..
--     on_project_delete = function(project) ..
--
--     config_example = string
-- }
--
-- They are stored in a list, to ensure ordering, first come first served.
-- unless _ext_priority is set, lower number makes for higher priority.
-- ****************************************************************************

local M = {
    _extensions = {},
}

local function priority_sort(a, b)
    local ap = a._ext_priority or 10
    local bp = b._ext_priority or 10
    return ap < bp
end

-- Returns the extensions as a table keyed on name.
-- The order is assigned as attribute _prj_id for introspection.
function M.extensions()
    local ret = {}
    for i, extension in ipairs(M._extensions) do
        ret[extension.name] = extension
        ret[extension.name]._prj_id = i
    end
    return ret
end

function M.register_extension(extension, host)
    if utils.empty(extension.name) then
        print 'project extension must have a name!'
        return
    end

    local plugs = M.extensions()
    if plugs[extension.name] then
        print('project extension with name ' .. extension.name .. ' already exists !')
        return
    end

    table.insert(M._extensions, extension)
    table.sort(M._extensions, priority_sort)

    if extension.project_extension_init then
        extension.project_extension_init(host)
    end
end

function M.unregister_extension(extension_name)

    local index = utils.array_find(M._extensions, function(plug)
        return plug.name == extension_name
    end)

    if not index then
        print('cannot unregister extension: ' .. extension_name .. ' not found')
        return
    end

    table.remove(M._extensions, index)
end

function M.publish_event(method, ...)
    for _, extension in ipairs(M._extensions) do
        if extension[method] then
            extension[method](...)
        end
    end
end

function M.read_project_templates()
    local ret = {}
    for _, extension in ipairs(M._extensions) do
        if extension.config_example then
            ret[extension.name] = extension.config_example
        end
    end
    return ret
end


-- function M.init()
--     M._extensions = {}
-- end

return M
