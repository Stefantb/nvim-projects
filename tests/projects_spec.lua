local proj = require 'projects'
local utils = require 'projects.utils'

-- describe('projects', function()
--     describe('default settings', function()
--         proj.setup { testing = true }
--
--         it('silent is false', function()
--             local config = proj.config()
--             assert.same(config.silent, false)
--         end)
--     end)
-- end)


describe('extensions', function()
    -- describe('default extensions', function()
    --     proj.setup {}
    --
    --     it('includes builds', function()
    --         assert.is_truthy(extensions.builds)
    --     end)
    --
    --     it('builds is first', function()
    --         assert.is_equal(extensions.builds._prj_id, 1)
    --     end)
    --
    --     it('can be disabled', function()
    --         proj.setup { extensions = { builds = false } }
    --         assert.is_falsy(extensions.builds)
    --     end)
    -- end)
    --

    local extensions = require'projects.extensions'

    local noname
    local thing1
    local thing2

    noname = {
        init_called = false,
        project_extension_init = function(host)
            noname.init_called = true
            noname.host = host
        end
    }
    thing1 = {
        name = 'thing',
        init_called = false,
        project_extension_init = function(host)
            thing1.init_called = true
            thing1.host = host
        end
    }
    thing2 = {
        name = 'thing',
        init_called = false,
        project_extension_init = function(host)
            thing2.init_called = true
            thing2.host = host
        end
    }

    local host = {}

    describe('registering', function()

        it('name attribute must be defined', function()
            extensions.register_extension { other = 'thing' }

            assert.is_false(noname.init_called)
        end)

        it('has project_extension_init called with the plugin host when registered', function()
            extensions.register_extension(thing1, host)

            assert.is_true(thing1.init_called)
            assert.is_equal(thing1.host, host)

            it('registration is rejected if name already exists', function()
                extensions.register_extension(thing2, host)
                assert.is_equal(extensions.extensions().thing, thing1)
                assert.is_false(thing2.init_called)
            end)
        end)
    end)
end)

local function to_dict(list)
    local ret = {}
    for _, v in ipairs(list) do
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
                    extensions = {
                        builds = utils.deepcopy(globals),
                    }
                }
            end,
        }

        it('has the global tasks after init', function()
            builds.project_extension_init(host)

            local build_list = to_dict(builds.build_list())
            local expected = utils.deepcopy(globals)
            verify_only_expected_keys(build_list, expected)
        end)

        it('has the union of global and project build tasks after on_project_open', function()
            builds.project_extension_init(host)

            local t_proj = {
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
            verify_only_expected_keys(build_list, expected)

            it('and only the global tasks again after on_project_close', function()
                builds.on_project_close(t_proj)

                build_list = to_dict(builds.build_list())
                expected = utils.deepcopy(globals)
                verify_only_expected_keys(build_list, expected)
            end)
        end)
    end)
end)

function table_compare(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or table_compare(value1, value2, ignore_mt) == false then
            print('not eq: ' .. tostring(value1) .. ' '.. tostring(value2))
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then
            print('missing key')
            return false
        end
    end
    return true
end


describe('utils', function()

    describe('merge', function()
        base = function()
            return {
                key1 = 'b1',
                key2 = 'b2',
                key3 = {
                    kkey1 = 'bb1',
                    kkey2 = 'bb2',
                    kkey3 = {
                        kkkey1 = 'bbb1',
                        kkkey2 = 'bbb2',
                    },
                },
            }
        end


        other = function()
            return {
                key2 = 'o2',
                key3 = {
                    kkey2 = 'oo2',
                    kkey3 = {
                        kkkey2 = 'ooo2',
                    },
                },
            }
        end

        it('merges level 1', function()
            local result = utils.table_merge(base(), other(), 1)
            local expected = {
                key1 = 'b1',
                key2 = 'o2',
                key3 = {
                    kkey2 = 'oo2',
                    kkey3 = {
                        kkkey2 = 'ooo2'
                    },
                },
            }
            local ok, eq = pcall(table_compare, result, expected ,true)
            if eq == true then
                assert.is_true(eq)
            else
                print(' equal \"' .. tostring(eq) .. '\"' )
                assert.is_equal(expected, result)
            end
        end)

        it('merges level 2', function()
            local result = utils.table_merge(base(), other(), 2)
            local expected = {
                key1 = 'b1',
                key2 = 'o2',
                key3 = {
                    kkey1 = 'bb1',
                    kkey2 = 'oo2',
                    kkey3 = {
                        kkkey2 = 'ooo2'
                    },
                },
            }
            local ok, eq = pcall(table_compare, result, expected ,true)
            if eq == true then
                assert.is_true(eq)
            else
                print(' equal \"' .. tostring(eq) .. '\"' )
                assert.is_equal(expected, result)
            end
        end)

        it('merges level 3', function()
            local result = utils.table_merge(base(), other(), 3)
            local expected = {
                key1 = 'b1',
                key2 = 'o2',
                key3 = {
                    kkey1 = 'bb1',
                    kkey2 = 'oo2',
                    kkey3 = {
                        kkkey1 = 'bbb1',
                        kkkey2 = 'ooo2'
                    },
                },
            }
            local ok, eq = pcall(table_compare, result, expected ,true)
            if eq == true then
                assert.is_true(eq)
            else
                print(' equal \"' .. tostring(eq) .. '\"' )
                assert.is_equal(expected, result)
            end
        end)


    end)

end)

