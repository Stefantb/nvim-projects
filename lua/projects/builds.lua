local utils = require'projects.utils'


-- ****************************************************************************
--
-- ****************************************************************************
local config = {}


-- ****************************************************************************
--
-- ****************************************************************************
local yabs = require("yabs")

local function build_list()
    return utils.keys(config.build_tasks)
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
local function update_build_tasks()

    config.build_tasks = {}

    -- Start with the globals.
    local global_tasks = config.host.config().build_tasks
    if global_tasks then
        for k,v in pairs(global_tasks) do
            config.build_tasks[k] = v
        end
    end

    -- Update with project specific ones.
    if config.current_project then
        local prj_builds = config.current_project.build_tasks
        if prj_builds then
            for k,v in pairs(prj_builds) do
                if config.build_tasks[k] then
                    print('Warning project build task: ' .. k .. ' overrides a global one.')
                end
                config.build_tasks[k] = v
            end
        end
    end
end


-- ****************************************************************************
--
-- ****************************************************************************
local plug = {
    name = 'builds'
}

function plug.on_init(host)
    config.host = host
    update_build_tasks()
end

function plug.on_load(current_project)
    config.current_project = current_project
    update_build_tasks()
end

function plug.on_close()
    config.current_project = nil
    update_build_tasks()
end


-- ****************************************************************************
-- Public API
-- ****************************************************************************
local M = {
    plugin = plug
}

function M.project_build(task_name)
    if not task_name or task_name == '' then
        if config.current_project then
            task_name = config.current_project.persistent:get('build_default', nil)
        end
    end

    local builds = build_list()
    if not utils.is_in_list(builds, task_name) then
        task_name = utils.prompt_selection(builds)
    end

    if task_name and task_name ~= '' then
        run_build(task_name)
    end
end

function M.project_build_set_default(task_name)
    if not task_name or task_name == '' then
        return
    end

    local builds = build_list()
    if not utils.is_in_list(builds, task_name) then
        return
        -- build = utils.prompt_selection(builds)
    end

    -- print('Setting build as default: ' .. build)
    if config.current_project then
        config.current_project.persistent:set('build_default', task_name)
    end
end

function M.project_build_cancel()
    cancel_build()
end

function M.builds_complete(_,_,_)
    return utils.join(build_list(), '\n')
end

M.build_list = build_list

return M
