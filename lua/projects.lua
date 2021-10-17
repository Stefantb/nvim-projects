-- ****************************************************************************
-- Keep some state away from direct access through M.
-- ****************************************************************************
local config = {
    project_dir          = "~/.config/nvim/projects/",
    silent               = false,
    current_project      = {},
    current_project_name = '',
    build_tasks          = {},
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
end


-- ****************************************************************************
-- Utilities
-- ****************************************************************************
local function restart_lsp()
    vim.cmd ':LspRestart'
end

local function ensure_dir(path_to_create)
    path_to_create = vim.fn.expand(path_to_create)
    if not vim.loop.fs_access(path_to_create, "r") then
        local success = vim.fn.mkdir(path_to_create, 'p')
        if not success then
            vim.api.nvim_err_writeln('Could not create folder '..path_to_create..' E: '..tostring(success))
        end
    end
    return path_to_create
end

local function ensure_projects_dir()
    return ensure_dir(config.project_dir)
end

local function join(list, sep)
    local str = ''
    local first = true
    for _, s in ipairs(list) do
        if first then
            str = str .. s
            first = false
        else
            str = str .. sep .. s
        end
    end
    return str
end

local function is_in_list(list, value)
    for _, v in pairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function split_newlines(text)
    local lines = {}
    for s in text:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end
    return lines
end

local function keys(table)
    local list = {}
    for key, _ in pairs(table) do
        list[#list+1] = key
    end
    return list
end

local function project_path(project)
    return vim.fn.expand(config.project_dir .. project .. '.lua')
end

local function current_project()
    return config.current_project
end


-- ****************************************************************************
-- Persistent state using JSON
-- ****************************************************************************
local function json_decode(data)
  local ok, result = pcall(vim.fn.json_decode, data)
  if ok then
    return result
  else
    return nil
  end
end

local function json_encode(data)
  local ok, result = pcall(vim.fn.json_encode, data)
  if ok then
    return result
  else
    return nil
  end
end

local function load_json(path)

    path = vim.fn.expand(path)
    if vim.fn.filereadable(path) == 0 then
        -- print('cannot read file: ' .. path )
        return nil
    end

    return json_decode(vim.fn.readfile(path))
end

local function save_json(path, table)
    local json_string = json_encode(table)
    -- print(json_string)

    ensure_projects_dir()
    path = vim.fn.expand(path)
    if vim.fn.writefile({json_string}, path) ~= 0 then
        return false
    end
    return true
end

local function current_persistent_path(typ_e)
    if typ_e == 'project' then
        if config.current_project_name ~= '' then
            return config.project_dir .. '/' .. config.current_project_name .. '.json'
        end
    elseif typ_e == 'projects' then
        return config.project_dir .. '/projects.json'
    end
    return nil
end


-- ****************************************************************************
--
-- ****************************************************************************
local Persistent = { }
Persistent.__index = Persistent

function Persistent:create(typ_e)
    local pers = {}             -- our new object
    setmetatable(pers,Persistent)  -- make Persistent handle lookup

    pers.state = {}
    pers.loaded = false
    pers.typ_e = typ_e

    return pers
end

function Persistent:try_load_if()
    if not self.loaded then
        local p_path = current_persistent_path(self.typ_e)
        if p_path then
            self.state = load_json(p_path) or {}
            self.loaded = true
        end
    end
end

function Persistent:try_save_if()
    local path = vim.fn.expand(current_persistent_path(self.typ_e))

    if vim.fn.filereadable(path) == 0 then
        -- print('file does not exist: ' .. path )
    else
        if not self.loaded then
            local state_before = self.state
            self:try_load_if()
            for key, value in pairs(state_before) do
                self.state[key] = value
            end
        end
    end

    if path then
        save_json(path, self.state)
    end
end

function Persistent:get(key, default)
    self:try_load_if()
    return self.state[key] or default
end

function Persistent:set(key, value)
    -- print('p.set '..key..':'..value)
    local before = self.state[key]
    if value ~= before then
        self.state[key] = value
        self:try_save_if()
    end
end

local persistent_project_state = Persistent:create('project')
local persistent_state = Persistent:create('projects')


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
        return is_in_list(list, session_name)
    end
    return false
end

function sessions.save(session_name)
    if session_name and session_name ~= "" then
        vim.cmd('execute \'SSave ' .. session_name .. '\'')
    end
end


-- ****************************************************************************
--
-- ****************************************************************************
local yabs = require("yabs")

local function build_list()
    return keys(config.build_tasks)
end

local function run_build(build)
    -- print('build using ' .. build)
    local task = config.build_tasks[build]
    if task then
        if task.executor == 'vim' then
            if task.compiler then
                vim.cmd('compiler ' .. task.compiler)
            end
            if task.makeprg then
                vim.opt.makeprg = task.makeprg
            end
            if task.errorformat then
                vim.opt.errorformat = task.errorformat
            end

            config.current_build_cancel = task.abortcommand

            vim.cmd(task.command)
        elseif task.executor == 'yabs' then
            if yabs then
                config.current_build_cancel = task.abortcommand
                yabs.run_command(task.command, task.output, task.options or {})
            else
                print('require\'yabs\' == nil')
            end
        end
    end
end

local function cancel_build()
    if config.current_build_cancel then
        vim.cmd(config.current_build_cancel)
    end
end


-- ****************************************************************************
--
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

local function prompt_selection(projects)
    local promptlist = {}
    for i, name in ipairs(projects) do
        promptlist[i] = i .. ': ' .. name
    end

    local selected = nil
    vim.fn.inputsave()
    local inp = vim.fn.inputlist(promptlist)
    vim.fn.inputrestore()
    if inp > 0 then
        selected = projects[inp]
    end

    return selected
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

local function activate_project(project_data)
    config.current_project = project_data
    config.current_project_name = project_data.project_name

    local settings = project_data.settings

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

    -- update the build task list
    if project_data.build_tasks then
        if config.build_tasks_setup then
            -- the  original has been saved so we start with that
            config.build_tasks = config.build_tasks_setup
        else
            -- save the original before munging it up
            config.build_tasks_setup = config.build_tasks
        end

        for k,v in pairs(project_data.build_tasks) do
            if config.build_tasks[k] then
                print('Warning project build task: ' .. k .. ' overrides global.')
            end
            config.build_tasks[k] = v
        end
    end

    vim.defer_fn(restart_lsp, 50)

    if config.silent == false then
        vim.defer_fn(function()
            vim.notify('[project-config] - ' .. M.current_project_name())
        end, 100)
    end
end

local function load_project_data(project_name)
    ensure_projects_dir()

    if project_name then

        local file_path = project_path(project_name)
        local project_data = dofile(file_path)

        if project_data then
            -- set some defaults
            project_data.project_name = project_name

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
        executor = 'yabs'
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
function M.project_open(project_name)
    local projects = project_list()
    if not is_in_list(projects, project_name) then
        project_name = prompt_selection(projects)
    end

    if project_name and project_name ~= '' then
        local project_data = load_project_data(project_name)
        activate_project(project_data)
        persistent_state:set('last_loaded_project', project_name)
    end
end

function M.project_close()
end

function M.project_delete(project_name)
    local projects = project_list()
    if not is_in_list(projects, project_name) then
        print('no project named: ' .. project_name)
    end

    if project_name and project_name ~= '' then
        print('Really delete ' .. project_name .. ' ? [y/n]')
        local answer = vim.fn.nr2char(vim.fn.getchar())
        if answer == 'y' then
            local file_path = project_path(project_name)
            if vim.fn.delete(file_path) == 0 then
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
        project_name = prompt_selection(projects)
    end

    local is_new = not is_in_list(projects, project_name)

    if project_name and project_name ~= '' then
        ensure_projects_dir()

        local projectfile = project_path(project_name)
        vim.cmd("edit " .. projectfile)
        if is_new then
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, split_newlines(project_template))
            -- vim.defer_fn(function()
            -- end, 500)
        end
    end
end

function M.projects_complete(_,_,_)
    return join(project_list(), '\n')
end

function M.show_current_project()
    print(vim.inspect(current_project()))
end

function M.project_build(build)
    if not build or build == '' then
        build = persistent_project_state:get('build_default', nil)
    end

    local builds = build_list()
    if not is_in_list(builds, build) then
        build = prompt_selection(builds)
    end

    if build and build ~= '' then
        run_build(build)
    end
end

function M.project_build_set_default(build)
    if not build or build == '' then
        return
    end

    local builds = build_list()
    if not is_in_list(builds, build) then
        return
        -- build = prompt_selection(builds)
    end

    -- print('Setting build as default: ' .. build)
    persistent_project_state:set('build_default', build)
end

function M.project_build_cancel()
    cancel_build()
end

function M.builds_complete(_,_,_)
    return join(build_list(), '\n')
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
    return current_project().project_root
end

function M.get_lsp_root(language, default)
    return current_project().lsp_root
end

function M.current_project_name()
    return current_project().project_name
end

return M
