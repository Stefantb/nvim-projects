local utils = require 'projects.utils'
local Config = require 'projects.config'

local function to_dict(list)
    local ret = {}
    for _, v in ipairs(list) do
        ret[v] = {}
    end
    return ret
end

describe('builds', function()
    describe('list', function()
        local builds = require 'projects.extensions.builds'
        local globals = {
            one = {},
            two = {},
        }

        local host = {
            global_config = function()
                return Config:new {
                    extensions = {
                        builds = utils.deepcopy(globals),
                    },
                }
            end,
        }

        it('has the global tasks after init', function()
            builds.project_extension_init(host)

            local build_list = to_dict(builds.build_list())
            local expected = utils.deepcopy(globals)
            utils.assert_table_equal(build_list, expected)
        end)

        it('has the union of global and project build tasks after on_project_open', function()
            builds.project_extension_init(host)

            local t_proj = Config:new {
                extensions = {
                    builds = {
                        two = {}, -- test overlap
                        three = {},
                        four = {},
                    },
                },
            }

            local expected = utils.deepcopy(globals)
            expected.three = {}
            expected.four = {}

            builds.on_project_open(t_proj)
            local build_list = to_dict(builds.build_list())
            utils.assert_table_equal(build_list, expected)

            it('and only the global tasks again after on_project_close', function()
                builds.on_project_close()

                build_list = to_dict(builds.build_list())
                expected = utils.deepcopy(globals)
                utils.assert_table_equal(build_list, expected)
            end)
        end)
    end)
end)
