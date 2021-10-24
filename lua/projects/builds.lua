local projects = require'projects'
local utils = require'projects.utils'

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

local plug = {
    name = 'builds'
}

function plug.on_load()
    local project = projects.current_project()
    config.current_project = project
    -- update the build task list
    if project.build_tasks then
        -- Start with a clean slate
        config.build_tasks = projects.global().build_tasks

        for k,v in pairs(project.build_tasks) do
            if config.build_tasks[k] then
                print('Warning project build task: ' .. k .. ' overrides global.')
            end
            config.build_tasks[k] = v
        end
    end
end

function plug.on_close()
    config.build_tasks = projects.global().build_tasks
    config.current_project = nil
end


-- ****************************************************************************
-- Public API
-- ****************************************************************************
local M = {}

function M.setup()
    projects.register_plugin(plug.name, plug)
    config.build_tasks = projects.global().build_tasks
end

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

return M
