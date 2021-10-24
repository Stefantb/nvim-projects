local persistent = require'projects.persistent'
local utils = require'projects.utils'


-- ****************************************************************************
-- Keep some state away from direct access through M.
-- ****************************************************************************
local config = {
    project_dir          = "~/.config/nvim/projects/",
    silent               = false,
    current_project      = {},
    current_project_name = '',
    build_tasks          = {},
    plugins              = {},
}


-- ****************************************************************************
-- Plugin setup.
-- ****************************************************************************
local M = {}

function M.setup(opts)
    if opts then
        for k, v in pairs(opts) do
            config[k] = v
        end
    end
    config.persistent = persistent:create(config.project_dir .. '/__projects__.json')
    require'projects.builds'.setup()
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


-- ****************************************************************************
-- Sessions interface relying on Startify
-- ****************************************************************************
local sessions = {}

function sessions.try_close_current()
    vim.cmd('execute \'SClose\'')
end

function sessions.load(session_name)
    if session_name and session_name ~= "" then
        vim.cmd('execute \'SLoad ' .. session_name .. '\'')
    end
end

function sessions.exists(session_name)
    if session_name and session_name ~= "" then
        local list = vim.fn['startify#session_list']('')
        return utils.is_in_list(list, session_name)
    end
    return false
end

function sessions.save(session_name)
    if session_name and session_name ~= "" then
        vim.cmd('execute \'SSave ' .. session_name .. '\'')
    end
end

function sessions.delete(session_name)
    if session_name and session_name ~= "" then
        vim.cmd('execute \'SDelete ' .. session_name .. '\'')
    end
end


-- ****************************************************************************
-- Project helpers
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
            local striped_name = name:match('(.+)%.lua$')
            if striped_name and striped_name ~= '' then
                projects[#projects+1] = striped_name
                -- projects[striped_name] = striped_name
            end
        end
    end
    return projects
end


local function is_project_root_ok(settings)
    local is_ok = true
    if settings.project_root then
        if not vim.loop.fs_access(settings.project_root, 'r') then
            vim.notify('project_root is not accessible: ' .. settings.project_root)
            is_ok = false
        end
    else
        vim.notify('project_root must be set !')
        is_ok = false
    end

    return is_ok
end

local function activate_project(project)
    config.current_project = project
    config.current_project_name = project.project_name

    local settings = project.settings

    sessions.try_close_current()
    if settings.session then
        if sessions.exists(settings.session) then
            sessions.load(settings.session)
        else
            sessions.save(settings.session)
        end
    end

    vim.cmd('execute \'cd ' .. settings.project_root .. '\'')

    if config.current_project.on_load then
        config.current_project.on_load()
    end

    for _, plugin_handlers in pairs(config.plugins) do
        if plugin_handlers.on_load then
            plugin_handlers.on_load()
        end
    end

    vim.defer_fn(utils.restart_lsp, 50)

    if config.silent == false then
        vim.defer_fn(function()
            vim.notify('[project-config] - ' .. M.current_project_name())
        end, 100)
    end
end

local function load_project(project_name)
    ensure_projects_dir()

    if project_name then

        local file_path = project_path(project_name)
        local project_data = dofile(file_path)

        if project_data then
            -- set some defaults
            project_data.project_name = project_name
            project_data.persistent = persistent:create(project_persistent_path(project_name))

            if not project_data.settings.session then
                project_data.settings.session = project_data.project_name
            end

            -- print(vim.inspect(project_data))
            if is_project_root_ok(project_data.settings) then
                return project_data
            end
        end
    end
    return nil
end

local project_template = [[
local M = {}

M.settings = {
    project_root = 'This is mandatory.',
    -- lsp_root = 'string for a global default, or a table with entries for languages.',
    -- lsp_root = {
        -- cpp = 'some path'
    -- }
    -- session = 'defaults to project name.'
}

M.build_tasks = {
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
}

M.on_load = function()
    vim.opt.makeprg = 'make -C m1200'
end
return M
]]


-- ****************************************************************************
-- Public API
-- ****************************************************************************
function M.global()
    return utils.read_only(config)
end

function M.current_project()
    return utils.read_only(config.current_project)
end

function M.register_plugin(plugin_name, plug)
    config.plugins[plugin_name] = plug
end

function M.project_open(project_name)
    local projects = project_list()
    if not utils.is_in_list(projects, project_name) then
        project_name = utils.prompt_selection(projects)
    end

    if project_name and project_name ~= '' then
        if config.current_project_name ~= '' then
            M.project_close()
        end

        local project_data = load_project(project_name)
        activate_project(project_data)
        config.persistent:set('last_loaded_project', project_name)
    end
end

function M.project_close()
    if config.current_project_name == '' then
        return
    end

    print('closing: ' .. config.current_project.project_name)

    for _, plugin_handlers in pairs(config.plugins) do
        if plugin_handlers.on_close then
            plugin_handlers.on_close()
        end
    end

    if config.current_project.on_close then
        config.current_project.on_close()
    end

    -- remove the project specific build tasks
    config.current_project = {}
    config.current_project_name = ''
end

function M.project_delete(project_name)
    local projects = project_list()
    if not utils.is_in_list(projects, project_name) then
        print('no project named: ' .. project_name)
    end

    if project_name and project_name ~= '' then
        print('Really delete ' .. project_name .. ' ? [y/n]')
        local answer = vim.fn.nr2char(vim.fn.getchar())
        if answer == 'y' then
             -- close project if currently open
             if config.current_project.project_name == project_name then
                 M.project_close()
             end
            local project_data = load_project(project_name)
            local file_path = project_path(project_name)
            if vim.fn.delete(file_path) == 0 then
                -- delete project json file
                local pers_path = project_persistent_path(project_name)
                vim.fn.delete(pers_path)

                -- delete session
                print('Delete associated session ' .. project_data.settings.session .. ' ? [y/n]')
                if answer == 'y' then
                    sessions.delete(project_data.settings.session)
                end
                print('Deleted ' .. project_name)
            else
                print('Deletion failed!')
            end
        end
    end
end

function M.project_edit(project_name)
    if not project_name or project_name == '' then
        project_name = config.current_project_name
    end

    local projects = project_list()

    if project_name == '' then
        project_name = utils.prompt_selection(projects)
    end

    local is_new = not utils.is_in_list(projects, project_name)

    if project_name and project_name ~= '' then
        ensure_projects_dir()

        local projectfile = project_path(project_name)
        vim.cmd("edit " .. projectfile)
        if is_new then
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.split_newlines(project_template))
            -- vim.defer_fn(function()
            -- end, 500)
        end
    end
end

function M.projects_complete(_,_,_)
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
            cmd = 'lua require\'projects\'.project_open(\'' .. project .. '\')'
        }
    end
    return list
end

-- ****************************************************************************
--
-- ****************************************************************************
function M.get_project_root()
    return M.current_project().project_root
end

function M.get_lsp_root(language, default)
    return M.current_project().lsp_root
end

function M.current_project_name()
    return M.current_project().project_name
end

return M
