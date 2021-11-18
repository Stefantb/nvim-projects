local utils = require 'projects.utils'

describe('utils', function()
    describe('merge', function()
        -- So we test the first three levels and then we beleive it to work for all levels.
        local base = function()
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

        local other = function()
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
                        kkkey2 = 'ooo2',
                    },
                },
            }

            utils.assert_table_equal(result, expected)
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
                        kkkey2 = 'ooo2',
                    },
                },
            }

            utils.assert_table_equal(result, expected)
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
                        kkkey2 = 'ooo2',
                    },
                },
            }

            utils.assert_table_equal(result, expected)
        end)
    end)
end)
