# nvim-projects

A neovim plugin to provide the concept of a project.

## Why A Project Plugin

I came to Vim already used to using editors that have projects. I always missed
having them but I resisted doing anything about it, because it isn't exactly the Vim way.

Until recently life without projects has been working great. I discovered [vim-startify](https://github.com/mhinz/vim-startify)
which made life pretty great for a while, it made working with sessions a wonderful experience
and I could come back to my projects with ease.

But then I started to work on a project that is organized as a monorepo. When working on that,
I want vim's working directory to stay at the repository root so project wide searches work
and my project drawer can show me what I want. But at the same time I want the LSP root to be
pointing to a subfolder, containing the sub project I am working on.

Why is that important?

Well I want ccls to create isolated caches for each project, because although they mostly
build the same sources, preprocessor definitions and build flags are very different.
It does get tired to clear the cache each time I switch projects. 
(The thing is here that ccls uses the path to the root its given, to distinguish the cache).
We could also just tell ccls where to store the cache on a per project basis, but that does
not remove the need for a per project configuration.

I have also been very content with running builds in a terminal besides my editor and that
works fine. I do miss running them in the editor for when things go wrong and I get the errors in
the quick fix list. 

Oh and of course, builds should be asynchronous.

And I dont want to mess with `exrc`.

I want nice things and here we are.


## What are the features

The idea is to make a very small and simple plugin that basically just
manages CRUD for a project and creates a simple foundation that can be
built upon. It should be quite transparent how you can add data on
a global level, and or per project and then retreive the data.

The basic project infrastructure does the following:
- [X] Commands to create, edit, delete, load and close projects.
- [X] Keep the project files in a configurable location outside
      the source repositories.
- [X] The ability to keep persistent state with each project.
- [X] Associated sessions with each project managed by [vim-startify](https://github.com/mhinz/vim-startify)
- [X] Easy integration to show projects listed on the startify screen.
- [X] Plug in API for extending functionality, build tasks is a showcase for this.
- [X] An API for other plugins (my config) to query the current project.

Immediately building upon this base, is the built in build management:
- [X] Commands to run build tasks, cancel builds and easily swicth the
      default task.
- [X] Provide a schema for declaring build tasks.
- [X] Merge global and per project build tasks, for presenting to the user.


Let's rely on startify to manage sessions. And it is best to use some other great plugins for 
running builds. I recommend [vim-dispatch](https://github.com/tpope/vim-dispatch) for that.
There is also an experimental integration for [yabs](https://github.com/pianocomposer321/yabs.nvim), a recent solution in the space.

There is a good chance that you are able to transparently use any build system using the 
same integration as dispatch, shown in the examples below. It simply relies on calling 
vim commands specified in the config.


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

Initialize the global settings by calling setup.
Its enough to call setup with an empty table. The defaults you can override are shown in the
example and this is also the place to add globally available build tasks, more on them later.
We also see a way to add plugins to the project, build management is implemented as a plugin,
it can be disabled by passing `{builds = false}` as the initializer.

``` lua
require("projects").setup{
    project_dir          = "~/.config/nvim/projects/",
    silent               = false,
    plugins = {
        builds = function() require'projects.builds'.setup() end
    },
    build_tasks          = {},
}

```


### Commands

Here are the commands. They come with completion.
There are no default keybindings so that is up to the user.

``` vim

:PEdit [project_name]   Edit a project file for a project that already exists
                        or provide a name for a new file to create and edit.

:POpen [project_name]   Open an existing project.

:PDelete [project_name] Delete the project file for a project that exists.
                        Note that the associated session will not be deleted
                        automatically.

:PClose                 Close the current project.

:PBuild [task_name]     Start a build with a configured task.
                        If no task name is given, the default task is run.
                        Tasks can be configured per project in the project file
                        or globally using the setup method.

:PBuildSetDefault       Set the default build task.

:PBuildCancel           Cancel a running build. Only available if the build executor
                        provides a way to cancel a build.

```
### Built in help

Remember to try this.
``` vim
:h projects
```

### The Project File

When you create a new project a buffer will open with a template for
a project you can edit to your hearts content and then save.

Here we see the way build tasks are defined and an example of how vim-dispatch and yabs can be used.
They are distinguished by the executor key.

The `on_project_open` function, if defined, will be called when a project is loaded, and similarly `on_project_close` is
called when the project is closed.

``` lua
local M = {
    root_dir = 'This is mandatory.',
    -- lsp_root = {
        -- sub_key = 'some path'
    -- }
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

## Plugin API

Plugins can register themselves using the `register_plugin` function.
This simply subscribes functions to receiving the `on_project_open` and `on_project_close` callbacks.

``` lua
require("projects").register_plugin{
    name = 'name',
    on_project_open = somefunc,
    on_project_close = somefunc
}
```
After receiving the events the query API can be used to access the project data.

## Query API


``` lua

-- Retreive the current global configuration as a table.
require("projects").config()

-- The following return the project as an object that has some convenience methods.

-- Retreive the project object or nil if no project is open.
require("projects").current_project()

-- Retreive the current project or an empty project if none is open.
-- This is useful when you want to use the objects query methods and defending
-- against the object being nil gains nothing. Its data is going to be nil anyway.
require("projects").current_project_or_empty()
```

### The Project object
The project object has some built in methods

``` lua
local project = require("projects").current_project_or_empty()

-- If key is not on the project object, look in the global config.
-- If not defined return the default.
local value = project:get(key, default)

-- Get a nested value.
-- If key or sub key is not on the project object, look in the global config.
-- If not defined return the default.
local sub_value = project:get_sub(key, sub_key, default)
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


