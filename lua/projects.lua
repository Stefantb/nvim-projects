local Persistent = require 'projects.persistent'
local utils = require 'projects.utils'
local extension_man = require('projects.extension_manager'):new()
local Config = require 'projects.config'

-- ****************************************************************************
--
-- ****************************************************************************
local current_project = nil
local config = {}

local function default_config()
    local hostname = vim.fn.hostname()
    if hostname then
        hostname = hostname .. '/'
    end
    return {
        project_dir = '~/.config/nvim/projects/' .. hostname,
        silent = false,
        extensions = {},
    }
end

-- ****************************************************************************
-- Utilities
-- ****************************************************************************
local function find_project_file(directory)
    local scan = vim.loop.fs_scandir(directory)
    while true do
        local name, typ = vim.loop.fs_scandir_next(scan)
        if name == nil then
            break
        end

        if typ == 'file' then
            m = name:match('%g*project.lua')
            if m and m ~= '' then
                return  name
            end
        end
    end

    return nil
end

-- Recursively scan for a .git folder or a .nvimproject folder until we reach the root of the filesystem
local function find_project_folder(directory)
    local scan = vim.loop.fs_scandir(directory)
    while true do
        local name, typ = vim.loop.fs_scandir_next(scan)
        if name == nil then
            break
        end

        if typ == 'directory' or typ == 'link' then
            if name == '.nvimproject' then
                if typ == 'link' then
                    local stuff = vim.loop.fs_stat(directory .. '/' .. name)
                    if stuff.type == 'directory' then
                        return directory .. '/' .. name
                    end
                else
                    return directory .. '/' .. name
                end
            end
        end
    end

    return nil
end

local function try_find_local_project()
    local directory = vim.fn.getcwd()
    while directory do
        local project_dir = find_project_folder(directory)
        if project_dir then
            local project_file = find_project_file(project_dir)
            if project_file then
                return {
                    project_dir = project_dir,
                    project_file = project_file,
                    project_name = project_file:match '(.+)%.lua$',
                }
            end
        end
        directory = vim.fn.fnamemodify(directory, ':h')
        if directory == '/' then
            break
        end
    end
    return nil
end
local function ensure_projects_dir()
    return utils.ensure_dir(config.project_dir)
end

local function ensure_local_project_dir()
    local path = vim.fn.getcwd() .. '/.nvimproject'
    return utils.ensure_dir(path)
end

local function local_project_dir(project)
    return project.root_dir .. '/.nvimproject'
end

local function project_path(project_name)
    local local_project = try_find_local_project()
    if local_project and project_name == local_project.project_name then
        local file_path = local_project.project_dir .. '/' .. local_project.project_file
        return vim.fn.expand(file_path)
    end
    return vim.fn.expand(config.project_dir .. project_name .. '.lua')
end

local function project_path2(project_name)
    local local_project = try_find_local_project()
    if local_project and project_name == local_project.project_name then
        local file_path = local_project.project_dir .. '/' .. local_project.project_file
        return { path=vim.fn.expand(file_path), is_local=true }
    end
    return { path=vim.fn.expand(config.project_dir .. project_name .. '.lua'), is_local=false }
end

local function project_persistent_path(project_name)
    return config.project_dir .. '/' .. project_name .. '.json'
end

local function empty(string)
    return string == nil or string == ''
end

-- ****************************************************************************
-- Project management
-- ****************************************************************************
---@class Project
---@field name? string
---@field path? string

---List all the projects available
---@return Project[]
local function project_list_()
    local dir = ensure_projects_dir()

    local projects = {}

    local local_project = try_find_local_project()
    if local_project then
        projects[#projects + 1] = {
            name = local_project.project_name,
            path = local_project.project_dir .. '/' .. local_project.project_file,
            project_dir = local_project.project_dir,
            is_local = true,
        }
    end

    local scan = vim.loop.fs_scandir(dir)
    while true do
        local name, typ = vim.loop.fs_scandir_next(scan)
        if name == nil then
            break
        end
        if typ == 'file' then

            local striped_name = name:match '(.+)%.lua$'
            if striped_name and striped_name ~= '' then
                projects[#projects + 1] = {
                    name = striped_name,
                    path = dir .. name,
                    dir = dir,
                    is_local = false,
                }
            end
        end
    end
    return projects
end

local function project_list()
    local projects = project_list_()
    for i, project in ipairs(projects) do
        projects[i] = project.name
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

    -- 2. cd to the project root.
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")

    -- 3. register the project as an extension
    project._ext_priority = 1
    extension_man:register_extension(project, host)

    -- 4. call extensions on load.
    extension_man:call_extensions('on_project_open', current_project)
end

local function project_close_current()
    if current_project then
        -- 1. call extensions on close.
        extension_man:call_extensions('on_project_close', current_project)

        -- 2. unregister the current project as a extension.
        extension_man:unregister_extension(current_project.name)

        -- 3. unassign the current project.
        current_project = nil
    end
end

local function load_project_from_file(project_name)
    ensure_projects_dir()

    if empty(project_name) then
        return nil
    end

    local file_info = project_path2(project_name)

    local ok, project_data = pcall(dofile, file_info.path)

    if ok == false then
        return nil
    end

    if project_data then
        local project = Config:new(project_data)

        -- set some defaults
        project.name = project_name
        project.unique_name = project_name
        project.is_local = file_info.is_local
        if project.is_local then
            project.root_dir = utils.local_project_path(file_info.path)
            project.unique_name = project.root_dir:gsub('/', '_')
        end
        project.persistent = Persistent:create(project_persistent_path(project.unique_name))

        if not project.extensions then
            project.extensions = {}
        end

        if is_project_root_ok(project) then
            return project
        end
    end
    return nil
end

local project_template = [[
-- local utils = require("projects.utils")
-- local project_root = utils.local_project_path(utils.script_path())
local M = {
    -- root_dir not needed if local project
    root_dir = '%s',

    extensions = {
%s
    },
}

function M.on_project_open()
    vim.opt.makeprg = 'make'
    --vim.cmd('PBuildSetDefault make')
end

function M.on_project_close()
end

return M
]]

local function render_project_template()
    local str = ''
    local templates = extension_man:call_extensions 'config_example'

    local indent = '        '
    for _, conf_str in pairs(templates) do
        -- str = str .. '-- ' .. source_name .. '\n'
        for line in utils.lines(conf_str) do
            if line ~= '' then
                str = str .. indent .. line .. '\n'
            else
                str = str .. line .. '\n'
            end
        end
    end

    return string.format(project_template, vim.fn.getcwd(), str)
end

local function register_commands()
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PEdit   lua require("projects").project_edit(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete POpen   lua require("projects").project_open(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PDelete lua require("projects").project_delete(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=*                                   PClose  lua require("projects").project_close()'

    vim.cmd [[
    fun ProjectsComplete(A,L,P)
    return luaeval('require("projects").projects_complete(A, L, P)')
    endfun
    ]]
end

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local M = {
    -- M being the extension host can provide unified user interaction,
    -- this could perhaps be overridden to use a telescope picker.
    prompt_selection = utils.prompt_selection,
    prompt_yes_no = utils.prompt_yes_no,
}

function M.setup(opts)
    config = utils.merge_first_level(default_config(), opts)

    config.persistent = Persistent:create(config.project_dir .. '/__projects__.json')

    register_commands()
end

function M.register_extension(extension)
    extension_man:register_extension(extension, M)
end

function M.global_config()
    return Config:new(config)
end

function M.is_project_open()
    return current_project ~= nil
end

function M.current_project_config()
    return Config:new(current_project)
end

function M.print_project_template()
    print(render_project_template())
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

    project_close_current()
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
        if M.is_project_open() and current_project.name == project_name then
            M.project_close()
        end
        local project = load_project_from_file(project_name)
        local file_path = project_path(project_name)
        if vim.fn.delete(file_path) == 0 then
            -- delete project json file
            local persistent_path = project_persistent_path(project_name)
            vim.fn.delete(persistent_path)

            if project then
                -- notify extensions
                extension_man:call_extensions('on_project_delete', project)

                vim.notify('Deleted ' .. project.name)
            end
        else
            vim.notify 'Deletion failed!'
        end
    end
end

function M.project_edit(project_name_)
    local project_name = project_name_ or ''
    if not project_name or project_name == ''  and current_project and current_project.name then
        project_name = current_project.name
    end

    P('project_name: ' .. project_name)
    local projects = project_list()
    P(projects)

    if empty(project_name) then
        project_name = M.prompt_selection(projects)
    end

    local is_new = not utils.is_in_list(projects, project_name)

    if project_name and project_name ~= '' then
        local projectfile = ''
        if is_new and M.prompt_yes_no('Local Project ? ') then
            ensure_local_project_dir()
            projectfile = vim.fn.getcwd() .. '/.nvimproject/' .. project_name .. '_project.lua'
        else
            ensure_projects_dir()
            projectfile = project_path(project_name)
        end
        vim.cmd('edit ' .. projectfile)
        if is_new then
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.split_newlines(render_project_template()))
        end
    end
end

function M.projects_complete(_, _, _)
    return utils.join(project_list(), '\n')
end

function M.show_current_project()
    print(vim.inspect(current_project))
end

function M.projects_list()
    return project_list_()
end

return M
