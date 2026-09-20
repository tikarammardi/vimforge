NVIM ?= nvim
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PLENARY ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim

export VIMFORGE_ROOT := $(ROOT)
export VIMFORGE_PLENARY := $(PLENARY)

PLENARY_CMD = --cmd "set rtp+=$(PLENARY)" --cmd "runtime! plugin/plenary.vim"

.PHONY: test test-one play demo clean

test:
	$(NVIM) --headless --clean $(PLENARY_CMD) \
	  --cmd "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua', sequential = true, keep_going = true }" \
	  --cmd "qa!"

# Usage: make test-one FILE=tests/spec/02_validators_spec.lua
test-one:
	@test -n "$(FILE)" || (echo "usage: make test-one FILE=tests/spec/<name>_spec.lua" && exit 1)
	$(NVIM) --headless --clean $(PLENARY_CMD) \
	  --cmd "PlenaryBustedFile $(FILE) { minimal_init = 'tests/minimal_init.lua' }" \
	  --cmd "qa!"

play:
	$(NVIM) --clean -u tests/minimal_init.lua -c "VimForge"

demo:
	$(NVIM) --headless --clean -u tests/minimal_init.lua \
	  -c "lua require('vimforge.demo').run()" -c "qa!"

clean:
	rm -rf tests/plenary.nvim
