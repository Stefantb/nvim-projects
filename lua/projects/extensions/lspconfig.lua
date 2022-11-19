-- vim.lsp.set_log_level("debug")
local nvim_lsp = require 'lspconfig'

local function on_attach(client, bufnr)
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end

    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    -- print('on attach!')

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = { noremap = true, silent = true }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<C-m>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
    buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.show_line_diagnostics()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
    buf_set_keymap('n', '<space>q', '<cmd>lua vim.diagnostic.set_loclist()<CR>', opts)
    buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.format { async = true }<CR>', opts)
    buf_set_keymap('x', '<space>f', '<cmd>lua vim.lsp.buf.range_formatting()<CR>', opts)

    -- print(vim.inspect(client.resolved_capabilities))

    require('lsp_signature').on_attach({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
        handler_opts = {
            border = 'single',
        },
    }, bufnr)
end

--[[ local capabilities = vim.lsp.protocol.make_client_capabilities() ]]
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- local servers = { 'ccls', 'lua', 'pyright', 'cmake'}
-- for _, lsp in ipairs(servers) do
--     nvim_lsp[lsp].setup {
--         on_attach = on_attach,
--         flags = {
--             debounce_text_changes = 150,
--         }
--     }
-- end

local special = {}

-- ****************************************************************************
-- sumneko lua
-- ****************************************************************************
function special.sumneko_lua()
    local system_name = ''
    --[[ if vim.fn.has 'mac' == 1 then ]]
    --[[     system_name = 'macOS' ]]
    --[[ elseif vim.fn.has 'unix' == 1 then ]]
    --[[     system_name = 'Linux' ]]
    --[[ elseif vim.fn.has 'win32' == 1 then ]]
    --[[     system_name = 'Windows' ]]
    --[[ else ]]
    --[[     print 'Unsupported system for sumneko' ]]
    --[[ end ]]

    local sumneko_root_path = '/home/stefantb/Dev/local-tools/lua-language-server'
    local sumneko_binary = sumneko_root_path .. '/bin/' .. system_name .. '/lua-language-server'

    local runtime_path = vim.split(package.path, ';')
    table.insert(runtime_path, 'lua/?.lua')
    table.insert(runtime_path, 'lua/?/init.lua')

    nvim_lsp.sumneko_lua.setup {
        cmd = { sumneko_binary, '-E', sumneko_root_path .. '/main.lua' },
        settings = {
            Lua = {
                runtime = {
                    -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                    version = 'LuaJIT',
                    -- Setup your lua path
                    path = runtime_path,
                },
                diagnostics = {
                    -- Get the language server to recognize the `vim` global
                    globals = { 'vim' },
                },
                workspace = {
                    -- Make the server aware of Neovim runtime files
                    library = vim.api.nvim_get_runtime_file('', true),
                },
                -- Do not send telemetry data containing a randomized but unique identifier
                telemetry = {
                    enable = false,
                },
                format = {
                    enable = true,
                    -- Put format options here
                    -- NOTE: the value should be STRING!!
                    defaultConfig = {
                        indent_style = "space",
                        indent_size = "4",
                    }
                },
            },
        },
        capabilities = capabilities,
        on_attach = on_attach,
    }
end

-- ****************************************************************************
-- ccls
-- ****************************************************************************
local util = require 'lspconfig/util'
local p_util = require 'projects/utils'

function special.ccls(ccls_config)
    local cache_dir = vim.fn.expand '~/.cache/nvim/ccls'
    local compdb_dir = ''
    local clang_settings = nil
    local lsp_root = nil

    if ccls_config then
        local project_lsp_cache = ccls_config.cache_subdir
        if project_lsp_cache then
            cache_dir = cache_dir .. '/' .. project_lsp_cache
        end

        compdb_dir = ccls_config.compdb_dir or ''

        clang_settings = ccls_config.clang
        lsp_root = ccls_config.lsp_root
        if lsp_root then
            lsp_root = vim.fn.expand(lsp_root)
        end
    end

    p_util.ensure_dir(cache_dir)

    local log_path = cache_dir .. '/' .. 'ccls.log'

    -- clang = {
    --     -- excludeArgs = { "-mlongcalls", "-Wno-frame-address", "-ffunction-sections", "-fdata-sections", "-Wall", "-Werror=all", "-Wno-error=unused-function", "-Wno-error=unused-variable", "-Wno-error=deprecated-declarations", "-Wextra", "-Wno-unused-parameter", "-Wno-sign-compare", "-ggdb", "-Og", "-fmacro-prefix-map=/home/stefantb/esp/tcp_server=.", "-fmacro-prefix-map=/home/stefantb/esp/esp-idf=IDF", "-fstrict-volatile-bitfields", "-Wno-error=unused-but-set-variable", "-fno-jump-tables", "-fno-tree-switch-conversion", "-std=gnu++11", "-fno-exceptions", "-fno-rtti" }
    --     -- extraArgs = {"--target=armv7m-none-eabi", "-isystem/usr/lib/gcc/arm-none-eabi/9.2.1/include/", "-isystem/usr/include/newlib", "-DTIDY"},
    -- }

    nvim_lsp.ccls.setup {
        cmd = { 'ccls', '--log-file=' .. log_path, '-v=1' },
        init_options = {
            cache = { directory = cache_dir },
            compilationDatabaseDirectory = compdb_dir,
            client = { snippetSupport = true },
            highlight = { lsRanges = true },
            clang = clang_settings,
        },
        root_dir = function(fname)
            -- print('lsp for file', fname)
            return lsp_root
                or util.root_pattern('compile_commands.json', '.ccls', 'compile_flags.txt', '.git')(fname)
                or util.path.dirname(fname)
        end,
        capabilities = capabilities,
        on_attach = on_attach,
    }

    vim.cmd('command! ClearCclsCache execute ":! rm -r ' .. cache_dir .. '/*"')
    vim.cmd('command! CclsLog execute ":e ' .. log_path .. '"')
end

-- ****************************************************************************
-- clangd
-- ****************************************************************************
-- nvim_lsp.clangd.setup{
--     init_options = {
--         usePlaceholders = true,
--         completeUnimported = true,
--         clangdFileStatus = true,
--         semanticHighlighting = true,
--     },
--     root_dir = function(fname)
--         -- project magic start --
--         local lsp_root = projects.current_project_or_empty():get_sub_sub('lspconfig', 'lsp_root', 'ccls', nil)
--         lsp_root = vim.fn.expand(lsp_root)
--         -- print('lsp root: '.. lsp_root)
--         -- project magic end --
--
--         return lsp_root or util.root_pattern('compile_commands.json', '.ccls', "compile_flags.txt", ".git")(fname)
--                         or util.path.dirname(fname)
--
--     end,
--     on_attach = on_attach,
--     capabilities = capabilities,
-- }

-- ****************************************************************************
-- null ls
-- ****************************************************************************
function special.null_ls()
    local null_ls = require 'null-ls'

    local filetypes = {
        'css',
        'scss',
        'less',
        'html',
        'json',
        'yaml',
        'vue',
        'typescript',
        'markdown',
        'graphql',
        'lua',
    }

    null_ls.setup {
        debug = false,
        sources = {
            null_ls.builtins.formatting.prettier.with {
                filetypes = filetypes,
            },
            null_ls.builtins.formatting.stylua.with {
                filetypes = filetypes,
            },
            null_ls.builtins.diagnostics.eslint.with {
                filetypes = filetypes,
            },
            null_ls.builtins.completion.spell.with {
                filetypes = filetypes,
            },
        },
        on_attach = on_attach,
    }
end

-- ****************************************************************************
--
-- ****************************************************************************
local putils = require 'projects.utils'

local function generic(lsp, config)
    config = config or {}

    local def = {
        capabilities = capabilities,
        on_attach = on_attach,
    }
    config = putils.merge_first_level(def, config)

    nvim_lsp[lsp].setup(config)
end

local function configure(lsp, config)
    if special[lsp] then
        special[lsp](config)
    else
        generic(lsp, config)
    end
end

local function restart_lsp()
    vim.cmd ':LspRestart'
end

local function do_configure(config)
    for lsp, config_ in pairs(config) do
        configure(lsp, config_)
    end
    vim.defer_fn(restart_lsp, 50)
end

local function un_configure(lsp)
    vim.lsp.stop_client(lsp)

    -- There is no good way to un-setup a client.
    -- Its at least better to not autostart clients that should be off.
    -- And revert to vanilla config.
    if nvim_lsp[lsp].autostart then
        local filetypes = nvim_lsp[lsp].filetypes
        if filetypes then
            for _, ft in ipairs(filetypes) do
                -- print('removing FileType autocommand for '.. lsp .. '  ' .. ft)
                vim.cmd(string.format('au! FileType %s', ft))
            end
        else
            print('TODO remove BufReadPost * autocommand for ' .. lsp)
        end
    end

    nvim_lsp[lsp].setup {
        autostart = false,
    }
end

local function do_un_configure(config)
    for lsp, _ in pairs(config) do
        un_configure(lsp)
    end
end

-- ****************************************************************************
-- Publid API
-- ****************************************************************************
local lspconfig = {
    name = 'lspconfig',
}

function lspconfig.project_extension_init(host)
    lspconfig.host = host
    local myconf = host.global_config():ext_config('lspconfig', {})
    do_configure(myconf)
end

function lspconfig.on_project_open(project)
    local myconf = project:ext_config('lspconfig', {})
    do_configure(myconf)
end

function lspconfig.on_project_close(project)
    local myconf = project:ext_config('lspconfig', {})
    do_un_configure(myconf)

    -- reinit with the global settings for servers that are in both
    myconf = lspconfig.host.global_config():ext_config('lspconfig', {})
    vim.defer_fn(function()
        do_configure(myconf)
    end, 50)
end

function lspconfig.config_example()
    return [[
lspconfig = {
    ccls = {
        lsp_root = 'repo root',
        cache_subdir = 'namespace for cache',
        compdb_dir = 'where is the compdb stored if not in the root',
        clang = {
            extraArgs = {
                "--target=armv7m-none-eabi",
                "-isystem/usr/lib/gcc/arm-none-eabi/9.2.1/include/",
                "-isystem/usr/include/newlib",
            },
        }
    },
},
]]
end

return lspconfig
