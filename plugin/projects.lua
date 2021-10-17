if vim.g.loaded_projects then
    return
end
vim.g.loaded_projects = true

vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PEdit   lua require("projects").project_edit(vim.fn.expand("<args>"))'
vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete POpen   lua require("projects").project_open(vim.fn.expand("<args>"))'
vim.cmd 'command! -nargs=* -complete=custom,ProjectsComplete PDelete lua require("projects").project_delete(vim.fn.expand("<args>"))'
vim.cmd 'command! -nargs=*                                   PClose  lua require("projects").project_close()'

vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuild           lua require("projects").project_build(vim.fn.expand("<args>"))'
vim.cmd 'command! -nargs=* -complete=custom,BuildsComplete PBuildSetDefault lua require("projects").project_build_set_default(vim.fn.expand("<args>"))'
vim.cmd 'command! -nargs=*                                 PBuildCancel     lua require("projects").project_build_cancel()'

vim.cmd([[
fun ProjectsComplete(A,L,P)
    return luaeval('require("projects").projects_complete(A, L, P)')
endfun
]])

vim.cmd([[
fun BuildsComplete(A,L,P)
    return luaeval('require("projects").builds_complete(A, L, P)')
endfun
]])

