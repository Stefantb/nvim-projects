local persistent = require 'projects.persistent'
local utils = require 'projects.utils'
local plugins = require 'projects.plugins'
local sessions = require 'projects.sessions_startify'

-- ****************************************************************************
--
-- ****************************************************************************
local current_project = nil
local config = {}

local function default_config()
    return {
        project_dir = '~/.config/nvim/projects/',
        silent = false,
        plugins = { builds = true },
    }
end

-- ****************************************************************************
-- Plugin management
-- ****************************************************************************
local function builtin_plugins()
    return {
        builds = require('projects.builds').plugin,
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

function Project:get_sub(key, sub_key, default)
    if self[key] then
        if self[key][sub_key] then
            return self['lsp_root'][sub_key]
        end
    elseif config[key] then
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
        if not vim.loop.fs_access(project.root_dir, 'r') then
            vim.notify('root_dir is not accessible: ' .. project.root_dir)
            is_ok = false
        end
    else
        vim.notify 'root_dir must be set !'
        is_ok = false
    end

    return is_ok
end

local function activate_project(project)
    -- 1. assign the current project.
    current_project = project

    -- 2. open the associated session.
    sessions.close()
    if project.session_name then
        if sessions.exists(project.session_name) then
            sessions.load(project.session_name)
        else
            sessions.save(project.session_name)
        end
    end

    -- 3. cd to the project root.
    vim.cmd("execute 'cd " .. project.root_dir .. "'")

    -- 4. call project on load.
    if project.on_load then
        project.on_load()
    end

    -- 5. call plugins on load.
    plugins.publish_event('on_load', current_project)

    -- 6. restart lsp TODO probably remove
    vim.defer_fn(utils.restart_lsp, 50)

    -- 7. notify user.
    if config.silent == false then
        vim.defer_fn(function()
            vim.notify('[project-config] - ' .. project.name)
        end, 100)
    end
end

local function load_project(project_name)
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

function M.on_load()
    vim.opt.makeprg = 'make'
end

function M.on_close()
    print('Goodbye then.')
end
return M
]]

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local M = {}

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
    return utils.read_only(current_project)
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
        project_name = utils.prompt_selection(projects)
    end

    if empty(project_name) then
        return
    end

    if current_project then
        M.project_close()
    end

    local project = load_project(project_name)
    if project then
        activate_project(project)
        config.persistent:set('last_loaded_project', project_name)
    else
        print('Unable to load project: ' .. project_name)
    end
end

function M.project_close()
    if not current_project then
        return
    end

    if not config.silent then
        print('closing: ' .. current_project.name)
    end

    if current_project.on_close then
        current_project.on_close()
    end
    plugins.publish_event('on_close', current_project)

    sessions.close()
    current_project = nil
end

function M.project_delete(project_name)
    local projects = project_list()
    if not utils.is_in_list(projects, project_name) then
        print('no project named: ' .. project_name)
    end

    if empty(project_name) then
        return
    end

    print('Really delete ' .. project_name .. ' ? [y/n]')
    local answer = vim.fn.nr2char(vim.fn.getchar())
    if answer == 'y' then
        -- close project if currently open
        if current_project.name == project_name then
            M.project_close()
        end
        local project_data = load_project(project_name)
        local file_path = project_path(project_name)
        if vim.fn.delete(file_path) == 0 then
            -- delete project json file
            local pers_path = project_persistent_path(project_name)
            vim.fn.delete(pers_path)

            -- delete session
            print('Delete associated session: ' .. project_data.session_name .. ' ? [y/n]')
            if answer == 'y' then
                sessions.delete(project_data.session_name)
            end
            print('Deleted ' .. project_name)
        else
            print 'Deletion failed!'
        end
    end
end

function M.project_edit(project_name)
    if not project_name or project_name == '' then
        project_name = current_project.name
    end

    local projects = project_list()

    if empty(project_name) then
        project_name = utils.prompt_selection(projects)
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
