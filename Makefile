test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"

style:
	stylua tests/*.lua lua/*.lua lua/projects/*.lua lua/projects/extensions/*.lua

.PHONY: test
