# nvim-projects

A neovim plugin to provide the concept of a project to the experience.

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

I want nice things and here we are. You to maybe ?


## What are the features

- [X] Commands to create, edit, delete and load projects.
- [X] Keep the project files outside the source repositories.
- [X] Commands to run build tasks, cancel builds and easily swicth the default task.
- [X] Associated sessions with each project managed by [vim-startify](https://github.com/mhinz/vim-startify)
- [X] Easy integration to show projects listed on the startify screen.
- [o] An API for other plugins (my config) to query the current project.
    - [X] A very minimalist and restricted set of query functions that do what I need.
    - [ ] Something more?


Its not the intention to create a behemoth thing that does everything, but rather try to 
make little glue layer in the middle that just helps things work uniformly.

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

Its enough to call setup with an empty table. The defaults you can override are shown in the 
example and this is also the place to add globally available build tasks, more on them later.

``` lua
require("projects").setup{
    project_dir = "~/.config/nvim/projects/",
    silent      = false,
    -- build_tasks = {
    --     task_one = { ... },
    --     task_two = { ... },
    -- },
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

``` vim
:h projects
```

### The Project File

When you create a new project a buffer will pop up with a template for a project you can
edit to your hearts content.

Here we see the way build tasks are defined and an example of how vim-dispatch and yabs can be used.
They are distinguished by the executor key.

The `on_load` function will be called when a project is loaded, but a symmetrical `on_close` is 
not available.

``` lua
local M = {}

M.settings = {
    project_root = 'This is mandatory.',
    -- lsp_root = 'string for a global default, or a table with entries for languages.',
    -- lsp_root = {
        -- cpp = 'some path'
    -- }
    -- session = 'defaults to project name.'
}

M.build_tasks = {
    task_name = {
        executor     = 'vim',
        compiler     = 'gcc',
        makeprg      = 'make -C mysubfolder',
        -- errorformat  = 'you will probably never have to use this'
        command      = 'Make release',
        abortcommand = 'AbortDispatch'

    },
    task_name2 = {
        executor = 'yabs'
        command = 'gcc main.c -o main',
        output = 'quickfix',
        opts = {
        },
    },
}

M.on_load = function()
    vim.opt.makeprg = 'make -C mysubfolder'
    vim.opt.expandtab = false  -- this project uses tabs ... grrr.
end
return M
```

## Query API

So far just this:
``` lua
require("projects").get_project_root()
require("projects").current_project_name()
require("projects").get_lsp_root(language, default)
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
        local project_root = project_settings.get_lsp_root('cpp', nil)
        -- project API magic end --

        return project_root or util.root_pattern('compile_commands.json', '.ccls', "compile_flags.txt", ".git")(fname)
                            or util.path.dirname(fname)
    end,
    capabilities = capabilities, -- comes from nvim-cmp for example.
    on_attach = on_attach,
}
vim.cmd('command! ClearCclsCache execute ":! rm -r '.. cache_dir .. '/*"')
vim.cmd('command! CclsLog execute ":e '.. log_path .. '"')
```

A crystal ball somewhere is telling of a need to push changes to subscribers
when a plugin is loaded. But so far this query API does the trick.

## Startify screen

Here is how I configure startify. This `ProjectList` function returns the right 
datastructure so all the available projects can be listed.

Thanks `mhinz` for making your plugin so easy to integrate with.

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


