local proj = require 'projects'
local utils = require 'projects.utils'

describe('projects', function()
    describe('default settings', function()
        proj.setup { testing = true }

        it('silent is false', function()
            local config = proj.config()
            assert.same(config.silent, false)
        end)
    end)
end)

describe('plugins', function()
    describe('default plugins', function()
        proj.setup {}

        it('includes builds', function()
            local plugins = proj.plugins()
            assert.is_truthy(plugins.builds)
        end)

        it('builds is first', function()
            local plugins = proj.plugins()
            assert.is_equal(plugins.builds._prj_id, 1)
        end)

        it('can be disabled', function()
            proj.setup { plugins = { builds = false } }
            local plugins = proj.plugins()
            assert.is_falsy(plugins.builds)
        end)
    end)

    describe('registering', function()
        proj.setup { testing = true }

        it('name attribute must be defined', function()
            proj.register_plugin { other = 'thing' }

            local plugins = proj.plugins()
            assert.is_falsy(plugins.thing)
        end)

        it('is rejected if name already exists', function()
            proj.register_plugin { name = 'thing', other = 1 }
            proj.register_plugin { name = 'thing', other = 2 }

            local plugins = proj.plugins()
            assert.is_equal(plugins.thing.other, 1)
        end)
    end)
end)

local function to_dict(list)
    local ret = {}
    for i, v in ipairs(list) do
        ret[v] = {}
    end
    return ret
end

local function verify_only_expected_keys(actual, expected)
    for k, v in pairs(actual) do
        if expected[k] then
            expected[k] = nil
        else
            expected[k] = v
        end
    end
    assert.is_equal(next(expected), nil)
end

describe('builds', function()
    describe('list', function()
        local builds = require 'projects.builds'
        local globals = {
            one = {},
            two = {},
        }

        local host = {
            config = function()
                return {
                    build_tasks = utils.deepcopy(globals),
                }
            end,
        }

        it('has the global tasks after init', function()
            builds.plugin.on_init(host)

            local build_list = to_dict(builds.build_list())
            local expected = utils.deepcopy(globals)
            verify_only_expected_keys(build_list, expected)
        end)

        it('has the union of global and project build tasks after on_load', function()
            builds.plugin.on_init(host)

            local t_proj = {
                build_tasks = {
                    two = {}, -- test overlap
                    three = {},
                    four = {},
                },
            }

            local expected = utils.deepcopy(globals)
            expected.three = {}
            expected.four = {}

            builds.plugin.on_load(t_proj)
            local build_list = to_dict(builds.build_list())
            verify_only_expected_keys(build_list, expected)

            it('and only the global tasks again after on_close', function()
                builds.plugin.on_close(host)

                build_list = to_dict(builds.build_list())
                expected = utils.deepcopy(globals)
                verify_only_expected_keys(build_list, expected)
            end)
        end)
    end)
end)
