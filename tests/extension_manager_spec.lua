local utils = require 'projects.utils'
local extensions = require 'projects.extension_manager'

local function make_extension(name, prio)
    local M = {
        _ext_priority = prio,
        name = name,
        init_called = false,
    }

    function M.project_extension_init(host)
        M.init_called = true
        M.host = host
    end

    function M.event_handler(data)
        data.events[#data.events + 1] = name
    end

    return M
end

describe('extension', function()
    describe('registering', function()
        local ext = extensions:new()

        local noname = make_extension(nil)
        local thing1 = make_extension 'thing'
        local thing2 = make_extension 'thing'
        local host = {}

        ext:register_extension(thing1, host)

        it('is rejected if a name attribute is missing', function()
            ext:register_extension { other = 'thing' }

            assert.is_false(noname.init_called)
        end)

        it('is rejected if the same name already exists', function()
            ext:register_extension(thing2, host)
            assert.is_equal(ext:extensions().thing, thing1)
            assert.is_false(thing2.init_called)
        end)

        describe('will', function()
            it('call project_extension_init', function()
                assert.is_true(thing1.init_called)

                it('with an extension host if supplied', function()
                    assert.is_equal(thing1.host, host)
                end)
            end)
        end)
    end)

    describe('dispatching', function()
        local ext = extensions:new()

        local ev1 = make_extension('ev1', 1)
        local ev2 = make_extension('ev2', 2)
        local ev3 = make_extension('ev3', 3)
        local host = {}

        -- The order of registration is at odds with the priority level.
        ext:register_extension(ev3, host)
        ext:register_extension(ev1, host)
        ext:register_extension(ev2, host)

        it('all registered extensions get called with the event in the order of priority', function()
            local data = { events = {} }
            ext:call_extensions('event_handler', data)
            utils.assert_table_equal(data.events, { 'ev1', 'ev2', 'ev3' })
        end)

        describe('unregistered extensions are', function()
            ext:unregister_extension 'ev2'

            it('removed from the list', function()
                local stuff = ext:extensions()

                for _, v in pairs(stuff) do
                    assert.not_equal(v.name, 'ev2')
                end
            end)

            it('not called with events', function()
                local data = { events = {} }

                ext:call_extensions('event_handler', data)

                utils.assert_table_equal(data.events, { 'ev1', 'ev3' })
            end)
        end)
    end)
end)
