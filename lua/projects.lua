local persistent = require 'projects.persistent'
local utils = require 'projects.utils'
local extensions = require 'projects.extensions'

-- ****************************************************************************
--
-- ****************************************************************************
local current_project = nil
local config = {}

local function default_config()
    return {
        project_dir = '~/.config/nvim/projects/',
        silent = false,
        extensions = {},
    }
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

function Project:get_sub_sub(ext, sub_key, sub_sub_key, default)
    if self.extensions[ext] then
        if self.extensions[ext][sub_key] then
            if self.extensions[ext][sub_key][sub_sub_key] then
                return self.extensions[ext][sub_key][sub_sub_key]
            end
        end
    end

    if config.extensions[ext] then
        if config.extensions[ext][sub_key] then
            if config.extensions[ext][sub_key][sub_sub_key] then
                return config.extensions[ext][sub_key][sub_sub_key]
            end
        end
    end
    return default
end

function Project:get_sub(ext, sub_key, default)
    if self.extensions[ext] then
        if self.extensions[ext][sub_key] then
            return self.extensions[ext][sub_key]
        end
    end

    if config.extensions[ext] then
        if config.extensions[ext][sub_key] then
            return config.extensions[ext][sub_key]
        end
    end
    return default
end

-- function Project:get(key, default)
--     if self[key] then
--         return self[key]
--     elseif config[key] then
--         return config[key]
--     end
--     return default
-- end

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

    -- 2. register the project as an extension
    project._ext_priority = 1
    extensions.register_extension(project, host)

    -- 3. cd to the project root.
    vim.cmd("execute 'cd " .. vim.fn.expand(project.root_dir) .. "'")

    -- 4. call extensions on load.
    extensions.publish_event('on_project_open', current_project)
end

local function project_close_current()
    if current_project then

        -- 1. call extensions on close.
        extensions.publish_event('on_project_close', current_project)

        -- 2. unregister the current project as a extension.
        extensions.unregister_extension(current_project.name)

        -- 3. unassign the current project.
        current_project = nil
    end
end

local function load_project_from_file(project_name)
    ensure_projects_dir()

    if empty(project_name) then
        return nil
    end

    local file_path = project_path(project_name)

    local ok, project_data = pcall(dofile, file_path)

    if ok == false then
        return nil
    end

    if project_data then
        local project = Project:new(project_data)

        -- set some defaults
        project.name = project_name
        project.persistent = persistent:create(project_persistent_path(project_name))

        if not project.extensions then
            project.extensions = {}
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
    -- silent = false,
    -- session_name = 'defaults to project name.'

    extensions = {
%s
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


local function render_project_template()
    local str = ''
    local templates = extensions.read_project_templates()

    local indent = '        '
    for source_name, conf_str in pairs(templates) do
        -- str = str .. '-- ' .. source_name .. '\n'
        for line in utils.lines(conf_str) do
            if line ~= '' then
                str = str .. indent .. line .. '\n'
            else
                str = str .. line .. '\n'
            end
        end
    end

    return string.format(project_template, str)
end


local function register_commands()
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PEdit   lua require("projects").project_edit(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete POpen   lua require("projects").project_open(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PDelete lua require("projects").project_delete(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=*                                   PClose  lua require("projects").project_close()'

    vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuild           lua require("projects.builds").project_build(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuildSetDefault lua require("projects.builds").project_build_set_default(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=*                                 PBuildCancel     lua require("projects.builds").project_build_cancel()'

    vim.cmd [[
    fun ProjectsComplete(A,L,P)
    return luaeval('require("projects").projects_complete(A, L, P)')
    endfun
    ]]

    vim.cmd [[
    fun BuildsComplete(A,L,P)
    return luaeval('require("projects.builds").builds_complete(A, L, P)')
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

    config.persistent = persistent:create(config.project_dir .. '/__projects__.json')

    register_commands()
end

function M.register_extension(extension)
    extensions.register_extension(extension, M)
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
        if current_project.name == project_name then
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
                extensions.publish_event('on_project_delete', project)

                vim.notify('Deleted ' .. project.name)
            end
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
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.split_newlines(render_project_template()))
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
