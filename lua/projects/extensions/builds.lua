local utils = require 'projects.utils'

-- ****************************************************************************
--
-- ****************************************************************************
local config = {}

-- ****************************************************************************
--
-- ****************************************************************************

local function build_list()
    return utils.keys(config.builds)
end

local function run_build(build)
    print('build using ' .. build)
    local task = config.builds[build]
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
local function update_build_tasks()
    config.builds = {}

    -- Start with the globals.
    local global_tasks = config.host.global_config():ext_config('builds', {})
    for k, v in pairs(global_tasks) do
        config.builds[k] = v
    end

    -- Update with project specific ones.
    if config.current_project then
        local prj_builds = config.current_project:ext_config('builds', {})
        for k, v in pairs(prj_builds) do
            if config.builds[k] then
                print('Warning project build task: ' .. k .. ' overrides a global one.')
            end
            config.builds[k] = v
        end
    end
end

local function register_commands()
    vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuild           lua require("projects.extensions.builds").project_build(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuildSetDefault lua require("projects.extensions.builds").project_build_set_default(vim.fn.expand("<args>"))'
    vim.cmd 'command! -nargs=*                                 PBuildCancel     lua require("projects.extensions.builds").project_build_cancel()'

    vim.cmd [[
    fun BuildsComplete(A,L,P)
    return luaeval('require("projects.extensions.builds").builds_complete(A, L, P)')
    endfun
    ]]
end

-- ****************************************************************************
-- Public API
-- ****************************************************************************
local builds = {
    name = 'builds',
}

function builds.project_extension_init(host)
    config.host = host
    update_build_tasks()

    register_commands()
end

function builds.on_project_open(current_project)
    config.current_project = current_project
    update_build_tasks()
end

function builds.on_project_close()
    print('Closing builds')
    config.current_project = nil
    update_build_tasks()
end

function builds.project_build(task_name)
    if not task_name or task_name == '' then
        if config.current_project then
            task_name = config.current_project.persistent:get('extensions.builds.default', nil)
        end
    end

    local b_list = build_list()
    if not utils.is_in_list(b_list, task_name) then
        task_name = utils.prompt_selection(b_list)
    end

    if task_name and task_name ~= '' then
        run_build(task_name)
    end
end

function builds.project_build_set_default(task_name)
    if not task_name or task_name == '' then
        return
    end

    local b_list = build_list()
    if not utils.is_in_list(b_list, task_name) then
        return
        -- build = utils.prompt_selection(b_list)
    end

    -- print('Setting build as default: ' .. build)
    if config.current_project then
        config.current_project.persistent:set('extensions.builds.default', task_name)
    end
end

function builds.project_build_cancel()
    cancel_build()
end

function builds.builds_complete(_, _, _)
    return utils.join(build_list(), '\n')
end

builds.build_list = build_list

function builds.config_example()
    return [[
builds = {
    task_name = {
        executor     = 'vim',
        compiler     = 'gcc',
        makeprg      = 'make',
        command      = 'Make release',
        abortcommand = 'AbortDispatch'

    },
},
]]
end

return builds
