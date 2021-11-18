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
--     config_example = function() .. -> string
-- }
--
-- They are stored in a list, to ensure ordering, first come first served.
-- unless _ext_priority is set, lower number makes for higher priority.
-- ****************************************************************************

local M = {}

function M:new()
    local me = {
        _extensions = {},
    }
    setmetatable(me, self)
    self.__index = self
    return me
end

local function priority_sort(a, b)
    local ap = a._ext_priority or 10
    local bp = b._ext_priority or 10
    return ap < bp
end

-- Returns the extensions as a table keyed on name.
-- The order is assigned as attribute _prj_id for introspection.
function M:extensions()
    local ret = {}
    for i, extension in ipairs(self._extensions) do
        ret[extension.name] = extension
        ret[extension.name]._prj_id = i
    end
    return ret
end

function M:register_extension(extension, host)
    if utils.empty(extension.name) then
        print 'project extension must have a name!'
        return
    end

    local plugs = self:extensions()
    if plugs[extension.name] then
        print('project extension with name ' .. extension.name .. ' already exists !')
        return
    end

    table.insert(self._extensions, extension)
    table.sort(self._extensions, priority_sort)

    if extension.project_extension_init then
        extension.project_extension_init(host)
    end
end

function M:unregister_extension(extension_name)
    local index = utils.array_find(self._extensions, function(plug)
        return plug.name == extension_name
    end)

    if not index then
        print('cannot unregister extension: ' .. extension_name .. ' not found')
        return
    end

    table.remove(self._extensions, index)
end

function M:call_extensions(method, ...)
    local ret = {}
    for _, extension in ipairs(self._extensions) do
        if extension[method] then
            local ok, result = pcall(extension[method], ...)
            ret[extension.name] = result
            if not ok then
                print('error calling extension ' .. extension.name .. '.' .. method .. 'returned : ' .. result)
            end
        end
    end
    return ret
end

return M
