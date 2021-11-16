# nvim-projects

A neovim plugin to provide the concept of a project.

## Why A Project Plugin

I came to Vim already used to using editors that have projects. I always missed
having them but I resisted doing anything about it, because it isn't exactly the Vim way.

Until recently life without projects has been working great. I discovered [vim-startify](https://github.com/mhinz/vim-startify)
which made life pretty great for a while, it made working with sessions a wonderful experience
and I could come back to my projects with ease.

The thing is though that some settings are not persisted in the sessions, like makeprg for example.

Then when I started working on a project that is organized as a monorepo. More friction showed up,
I want vim's working directory to stay at the repository root so project wide searches work
and my project drawer can show me what I want. But at the same time I want project specific LSP settings.

Why is that important?

Well I want ccls to create isolated caches for each project, because although they mostly
build the same sources, preprocessor definitions and build flags are very different.
It does get tired to clear the cache each time I switch projects. 

I have also been very content with running builds in a terminal besides my editor and that
works fine. I do miss running them in the editor for when things go wrong and I get the errors in
the quick fix list. 

And I dont want to mess with `exrc`.

I think its time to attempt scratching this itch, and have fun in the way.


## How does it work

The idea is to make a very small and simple plugin that basically
manages opening, closing and CRUD for projects.
Internally it also provides ways to query settings and subscribe to lifecycle events such as
`on_project_open`, `on_project_close` and `on_project_delete`.

In the current implementation the project itself is a lua table providing a key value store.
There is also a corresponding global lua table that can provide defauls for projects to override.


The basic project infrastructure does the following:
- [X] Commands to create, edit, delete, open and close projects.
- [X] Keep the project files in a configurable location outside
      the source repositories.
- [X] The ability to keep persistent programatically mutable state with each project.
- [X] Plug in API for extending functionality.
    - [X] Subscribe to lifecycle events.
    - [X] Query settings.

### Default project plugins
On its own the project infrastructure does nothing interesting so there are some project plugins
that come built in.

##### Sessions
Let's rely on startify to manage sessions.

- [X] Associated sessions with each project managed by [vim-startify](https://github.com/mhinz/vim-startify)
- [X] Easy integration to show projects listed on the startify screen.

##### Builds
An integration with [vim-dispatch](https://github.com/tpope/vim-dispatch) to specify tasks to run
and provide a way to quickly switch between them.
There is also an experimental integration for [yabs](https://github.com/pianocomposer321/yabs.nvim), a recent solution in the space.

- [X] Commands to run build tasks, cancel builds and easily swicth the
      default task.
- [X] Merge global and per project build tasks, for presenting to the user.

##### LSPconfig
WIP....


## Installation

#### [Packer](https://github.com/wbthomason/packer.nvim)

``` lua
use {
    'stefantb/nvim-projects',
    requires = {
        'mhinz/vim-startify', 
        'tpope/vim-dispatch'  -- not really a hard requirement.
    },
}

```

## Usage

Initialize the plugin and the global settings by calling setup.
Its enough to call setup with an empty table.
All the keys and values you put into this table become the global defaults that projects can override.
Default plugins can be disabled passing `plugins = {<plug name> = false}`.

``` lua
require("projects").setup{
    project_dir = '~/.config/nvim/projects/',
    silent = false,
    plugins = { builds = true, sessions = true },
}

```


### Commands

Here are the commands. There is tab completion when relevant.

#### Projects
``` vim
:PEdit [project_name]   "Edit a project file for a project that already exists
                        "or provide a name for a new file to create and edit.

:POpen [project_name]   "Open an existing project.

:PDelete [project_name] "Delete the project file for a project that exists.
                        "Note that the associated session will not be deleted
                        "automatically.

:PClose                 "Close the current project.
```

#### Builds
``` vim
:PBuild [task_name]     "Start a task.
                        "If no task name is given, the default task is run.
                        "Tasks can be configured per project in the project file
                        "or globally using the setup method.

:PBuildSetDefault       "Set the default build task.

:PBuildCancel           "Cancel a running build.
                        "Note ! Only available if the build executor
                        "provides a way to cancel a build.
```




### Built in help

Remember to try this.
``` vim
:h projects
```

## Plugin API

Plugins can be registered using the `register_plugin` function.
Implement any of the callback functions to receive the events.

When a plugin is registered, `project_plugin_init` is immediately called with
the plugin host as the argument. The plugin host is the project plugin itself.
``` lua
require("projects").register_plugin{
    name = 'a unique name',
    project_plugin_init = function(plugin_host)end,
    on_project_open = function(project)end,
    on_project_close = function(project)end,
    on_project_delete = function(project)end

}
```
After receiving the events the query API can be used to access the project data.


### The Project File
When you create a new project a buffer will open with a template for
a project you can edit to your hearts content and then save.

Here we see the way build tasks are defined and an example of how vim-dispatch and yabs can be used.
They are distinguished by the executor key.

Projects are automatically registered as plugins.

``` lua
local M = {
    root_dir = 'This is mandatory.',
    -- lsp_config = {}
    -- session_name = 'defaults to project name.'

    build_tasks = {
        task_name = {
            executor     = 'vim',
            compiler     = 'gcc',
            makeprg      = 'make',
            command      = 'Make release',
            abortcommand = 'AbortDispatch'

        },
        task_name2 = {
            executor = 'yabs',
            command = 'gcc main.c -o main',
            output = 'quickfix',
            opts = {
            },
        },
    }
}

function M.on_project_open()
    vim.opt.makeprg = 'make'
end

function M.on_project_close()
    print('Goodbye then.')
end
return M

```

## Plugin Host


``` lua

plugin_host = {

    -- Returns the global config as a read only table.
    config = function() end,

    -- Retreive the project object or nil if no project is open.
    current_project = function() end,

    -- Retreive the current project or an empty project if none is open.
    -- This is useful when you want to use the objects query methods and defending
    -- against the object being nil gains nothing. Its data is going to be nil anyway.
    current_project_or_empty = function() end,

    -- Prompt the user for a selection.
    -- Returns the selected item.
    prompt_selection = function(select_list) end,

    -- Prompt the user for a yes or no question.
    -- Returns a bool.
    prompt_yes_no = function(question_string) end,

    -- log functions.
    -- logi
    -- logw
    -- loge
}


```

## Query API


### The Project object
Projects tables are enhanced with methods to ease querying.

``` lua
local project = require("projects").current_project_or_empty()

-- If key is not on the project object, look in the global config.
-- If not defined return the default.
local value = project:get(key, default)

-- Get a nested value.
-- If key or sub key is not on the project object, look in the global config.
-- If not defined return the default.
local sub_value = project:get_sub(key, sub_key, default)


-- Get a nested value.
-- If key, sub_key or sub_sub_key is not on the project object, look in the global config.
-- If not defined return the default.
local sub_sub_value = project:get_sub_sub(key, sub_key, sub_sub_key, default)
```

The one integration, that started this whole thing is best showcased with a real example 
of how lspconfig can consume information. Here the `root_dir` function will get called every time
a client is attached to a buffer.

``` lua
local project_settings = require'projects'
local util = require 'lspconfig/util'

local log_path = vim.fn.expand('~/.cache/nvim/ccls/ccls.log')
local cache_dir = vim.fn.expand('~/.cache/nvim/ccls')

nvim_lsp.ccls.setup {
    cmd = {'ccls', '--log-file='..log_path},
    init_options = {
        cache = {directory = cache_dir},
        compilationDatabaseDirectory = '',
        client = {snippetSupport = true},
        highlight = { lsRanges = true },
    },
    root_dir = function(fname)
        -- project API magic start --
        local lsp_root = projects.current_project_or_empty():get_sub('lsp_root','ccls', nil)
        -- project API magic end --

        return lsp_root or util.root_pattern('compile_commands.json', '.ccls', "compile_flags.txt", ".git")(fname)
                        or util.path.dirname(fname)
    end,
    capabilities = capabilities, -- comes from nvim-cmp for example.
    on_attach = on_attach,
}
vim.cmd('command! ClearCclsCache execute ":! rm -r '.. cache_dir .. '/*"')
vim.cmd('command! CclsLog execute ":e '.. log_path .. '"')
```

## Build Tasks

## Startify Screen

Here is how I configure startify. This `ProjectList` function returns the right 
datastructure so all the available projects can be listed.

``` vim

function! ProjectList()
    return luaeval('require("projects").projects_startify_list()')
endfun

let g:startify_lists = [
          \ { 'type': function('ProjectList'),  'header': ['   Projects'] },
          \ { 'type': 'files',                  'header': ['   Files']    },
          \ { 'type': 'dir',                    'header': ['   Current Directory '. getcwd()] },
          \ ]

```

## Roadmap And Contribution


