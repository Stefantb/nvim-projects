local persistent = require 'projects.persistent'
local utils = require 'projects.utils'
local plugins = require 'projects.plugins'

-- ****************************************************************************
--
-- ****************************************************************************
local current_project = nil
local config = {}

local function default_config()
    return {
        project_dir = '~/.config/nvim/projects/',
        silent = false,
        plugins = { builds = true, sessions = true },
    }
end

-- ****************************************************************************
-- Plugin management
-- ****************************************************************************
local function builtin_plugins()
    return {
        builds = require('projects.builds').plugin,
        sessions = require('projects.sessions_startify')
    }
end

local function init_plugins(plug_config, host)
    plugins.init()

    local builtin = builtin_plugins()
    for plugin_name, value in pairs(plug_config) do
        if value ~= false then
            if builtin[plugin_name] then
                plugins.register_plugin(builtin[plugin_name], host)
            else
                print('no built in project plugin ' .. plugin_name)
            end
        end
    end
end

-- ****************************************************************************
-- Utilities
-- ****************************************************************************
local function ensure_projects_dir()
    return utils.ensure_dir(config.project_dir)
end

local function project_path(project)
    return vim.fn.expand(config.project_dir .. project .. '.lua')
end

local function project_persistent_path(project_name)
    return config.project_dir .. '/' .. project_name .. '.json'
end

local function empty(string)
    return string == nil or string == ''
end

-- ****************************************************************************
-- Project object
-- ****************************************************************************
local Project = {}

function Project:new(data)
    data = data or {}
    setmetatable(data, self)
    self.__index = self
    return data
end

function Project:get_sub_sub(key, sub_key, sub_sub_key, default)
    if self[key] then
        if self[key][sub_key] then
            if self[key][sub_key][sub_sub_key] then
                return self[key][sub_key][sub_sub_key]
            end
        end
    end

    if config[key] then
        if config[key][sub_key] then
            if config[key][sub_key][sub_sub_key] then
                return config[key][sub_key][sub_sub_key]
            end
        end
    end
    return default
end

function Project:get_sub(key, sub_key, default)
    if self[key] then
        if self[key][sub_key] then
            return self[key][sub_key]
        end
    end

    if config[key] then
        if config[key][sub_key] then
            return config[key][sub_key]
        end
    end
    return default
end

function Project:get(key, default)
    if self[key] then
        return self[key]
    elseif config[key] then
        return config[key]
    end
    return default
end

-- ****************************************************************************
-- Project management
-- ****************************************************************************
local function project_list()
    local dir = ensure_projects_dir()

    local projects = {}
    local scan = vim.loop.fs_scandir(dir)
    while true do
        local name, typ = vim.loop.fs_scandir_next(scan)
        if name == nil then
            break
        end
        if typ == 'file' then
            local striped_name = name:match '(.+)%.lua$'
            if striped_name and striped_name ~= '' then
                projects[#projects + 1] = striped_name
            end
        end
    end
    return projects
end

local function is_project_root_ok(project)
    local is_ok = true
    if project.root_dir then
        if not vim.loop.fs_access(vim.fn.expand(project.root_dir), 'r') then
            vim.notify('root_dir is not accessible: ' .. project.root_dir)
            is_ok = false
        end
    else
        vim.notify 'root_dir must be set !'
        is_ok = false
    end

    return is_ok
end

local function activate_project(project, host)
    -- 1. assign the current project.
    current_project = project

    -- 2. register the project as a plugin
    project._plug_priority = 1
    plugins.register_plugin(project, host)

    -- 3. cd to the project root.
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")

    -- 4. call plugins on load.
    plugins.publish_event('on_project_open', current_project)
end

local function load_project_from_file(project_name)
    ensure_projects_dir()

    if empty(project_name) then
        return nil
    end

    local file_path = project_path(project_name)
    local project_data = dofile(file_path)

    if project_data then
        local project = Project:new(project_data)

        -- set some defaults
        project.name = project_name
        project.persistent = persistent:create(project_persistent_path(project_name))

        if not project.session_name then
            project.session_name = project.name
        end

        -- print(vim.inspect(project))
        if is_project_root_ok(project) then
            return project
        end
    end
    return nil
end

local project_template = [[
local M = {
    root_dir = 'This is mandatory.',
    -- lsp_root = {
        -- sub_key = 'some path'
    -- }
    -- session_name = 'defaults to project name.'

    build_tasks = {
        task_name = {
            executor     = 'vim',
            compiler     = 'gcc',
            makeprg      = 'make',
            command      = 'Make release',
            abortcommand = 'AbortDispatch'

        },
        task_name2 = {
            executor = 'yabs',
            command = 'gcc main.c -o main',
            output = 'quickfix',
            opts = {
            },
        },
    },
    plugins = {
        'projects.builds'
    },
}

function M.on_project_open()
    vim.opt.makeprg = 'make'
end

function M.on_project_close()
    print('Goodbye then.')
end
return M
]]

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local M = {
    -- M being the plugin host can provide unified user interaction,
    -- this could perhaps be overridden to use a telescope picker.
    prompt_selection = utils.prompt_selection,
    prompt_yes_no = utils.prompt_yes_no,
}

function M.setup(opts)
    config = utils.merge_first_level(default_config(), opts)

    config.persistent = persistent:create(config.project_dir .. '/__projects__.json')
    init_plugins(config.plugins, M)

    -- allow a little more introspection during testing.
    if config.testing then
        M.plugins = plugins.plugins
        M.project_activate = activate_project
    end
end

function M.register_plugin(plugin)
    plugins.register_plugin(plugin, M)
end

function M.config()
    return utils.read_only(config)
end

function M.current_project()
    return current_project
end

function M.current_project_or_empty()
    if not current_project then
        return Project:new()
    end
    return M.current_project()
end

function M.project_open(project_name)
    local projects = project_list()
    if not utils.is_in_list(projects, project_name) then
        project_name = M.prompt_selection(projects)
    end

    if empty(project_name) then
        return
    end

    if current_project then
        M.project_close()
    end

    local project = load_project_from_file(project_name)
    if project then
        activate_project(project, M)
        config.persistent:set('last_loaded_project', project_name)

        -- notify the user
        if config.silent == false then
            vim.defer_fn(function()
                vim.notify('[project-config] - ' .. project.name)
            end, 100)
        end

    else
        vim.notify('Unable to load project: ' .. project_name)
    end
end

function M.project_close()
    if not current_project then
        return
    end

    if not config.silent then
        vim.notify('closing: ' .. current_project.name)
    end

    if current_project.on_project_close then
        current_project.on_project_close()
    end

    plugins.publish_event('on_project_close', current_project)

    current_project = nil
end

function M.project_delete(project_name)
    local projects = project_list()
    if not utils.is_in_list(projects, project_name) then
        vim.notify('no project named: ' .. project_name)
    end

    if empty(project_name) then
        return
    end

    if M.prompt_yes_no('Really delete ' .. project_name) then
        -- close project if currently open
        if current_project.name == project_name then
            M.project_close()
        end
        local project = load_project_from_file(project_name)
        local file_path = project_path(project_name)
        if vim.fn.delete(file_path) == 0 then

            -- delete project json file
            local persistent_path = project_persistent_path(project_name)
            vim.fn.delete(persistent_path)

            -- notify plugins
            plugins.publish_event('on_project_delete', project)

            vim.notify('Deleted ' .. project.name)
        else
            vim.notify('Deletion failed!')
        end
    end
end

function M.project_edit(project_name)
    if not project_name or project_name == '' then
        project_name = current_project.name
    end

    local projects = project_list()

    if empty(project_name) then
        project_name = M.prompt_selection(projects)
    end

    local is_new = not utils.is_in_list(projects, project_name)

    if project_name and project_name ~= '' then
        ensure_projects_dir()

        local projectfile = project_path(project_name)
        vim.cmd('edit ' .. projectfile)
        if is_new then
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.split_newlines(project_template))
        end
    end
end

function M.projects_complete(_, _, _)
    return utils.join(project_list(), '\n')
end

function M.show_current_project()
    print(vim.inspect(M.current_project()))
end

function M.projects_startify_list()
    local list = {}
    for i, project in ipairs(project_list()) do
        list[i] = {
            line = project,
            cmd = "lua require'projects'.project_open('" .. project .. "')",
        }
    end
    return list
end

return M
