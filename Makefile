PREFIX ?= $(HOME)/.local

SHARE_DIR  = $(PREFIX)/share/slurmctl
BIN_DIR    = $(PREFIX)/bin
BASH_COMP  = $(PREFIX)/share/bash-completion/completions
FISH_COMP  = $(PREFIX)/share/fish/vendor_completions.d
FISH_FUNC  = $(PREFIX)/share/fish/vendor_functions.d

# Source files
LIB_SRC     = $(wildcard lib/*.sh)
LIBEXEC_SRC = $(wildcard libexec/slurmctl/*.sh)
MAIN_SRC    = slurmctl

# Installed targets
LIB_DST     = $(LIB_SRC:%=$(SHARE_DIR)/%)
LIBEXEC_DST = $(LIBEXEC_SRC:%=$(SHARE_DIR)/%)
MAIN_DST    = $(SHARE_DIR)/$(MAIN_SRC)
BIN_LINK    = $(BIN_DIR)/slurmctl
BASH_DST    = $(BASH_COMP)/slurmctl
FISH_DST    = $(FISH_COMP)/slurmctl.fish
FISHFN_DST  = $(FISH_FUNC)/slurmctl.fish
VERSION_DST = $(SHARE_DIR)/VERSION

ALL_DST = $(MAIN_DST) $(LIB_DST) $(LIBEXEC_DST) $(BIN_LINK) \
          $(BASH_DST) $(FISH_DST) $(FISHFN_DST) $(VERSION_DST)

# Colors
C_CYAN    = \033[36m
C_GREEN   = \033[32m
C_YELLOW  = \033[33m
C_RED     = \033[31m
C_DIM     = \033[2m
C_RESET   = \033[0m

.PHONY: install uninstall patch clean

install: $(ALL_DST)
	@printf "$(C_GREEN)done$(C_RESET) $(C_DIM)$(PREFIX)$(C_RESET)\n"

# Main script
$(MAIN_DST): $(MAIN_SRC) | $(SHARE_DIR)
	@printf "  $(C_CYAN)install$(C_RESET)  %s $(C_DIM)-> %s$(C_RESET)\n" "$(<F)" "$@"
	@cp $< $@
	@chmod +x $@

# lib/*.sh
$(SHARE_DIR)/lib/%.sh: lib/%.sh | $(SHARE_DIR)/lib
	@printf "  $(C_CYAN)install$(C_RESET)  lib/%s $(C_DIM)-> %s$(C_RESET)\n" "$(<F)" "$@"
	@cp $< $@

# libexec/slurmctl/*.sh
$(SHARE_DIR)/libexec/slurmctl/%.sh: libexec/slurmctl/%.sh | $(SHARE_DIR)/libexec/slurmctl
	@printf "  $(C_CYAN)install$(C_RESET)  libexec/%s $(C_DIM)-> %s$(C_RESET)\n" "$(<F)" "$@"
	@cp $< $@

# Symlink
$(BIN_LINK): $(MAIN_DST) | $(BIN_DIR)
	@printf "  $(C_YELLOW)link$(C_RESET)     %s $(C_DIM)-> %s$(C_RESET)\n" "$@" "$(MAIN_DST)"
	@ln -sf $(MAIN_DST) $@

# Completions
$(BASH_DST): completions/slurmctl.bash | $(BASH_COMP)
	@printf "  $(C_CYAN)install$(C_RESET)  completions/bash $(C_DIM)-> %s$(C_RESET)\n" "$@"
	@cp $< $@

$(FISH_DST): completions/slurmctl.fish | $(FISH_COMP)
	@printf "  $(C_CYAN)install$(C_RESET)  completions/fish $(C_DIM)-> %s$(C_RESET)\n" "$@"
	@cp $< $@

$(FISHFN_DST): functions/slurmctl.fish | $(FISH_FUNC)
	@printf "  $(C_CYAN)install$(C_RESET)  functions/fish $(C_DIM)-> %s$(C_RESET)\n" "$@"
	@cp $< $@

# Version stamp (always update on install)
.PHONY: $(VERSION_DST)
$(VERSION_DST): | $(SHARE_DIR)
	@printf "  $(C_DIM)version$(C_RESET)  %s\n" "$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
	@echo "$$(git rev-parse --short HEAD 2>/dev/null || echo unknown) ($$(git branch --show-current 2>/dev/null || echo unknown))" > $@

# Directory creation
$(SHARE_DIR) $(SHARE_DIR)/lib $(SHARE_DIR)/libexec/slurmctl $(BIN_DIR) $(BASH_COMP) $(FISH_COMP) $(FISH_FUNC):
	@mkdir -p $@

patch:
	@bash $(CURDIR)/patch.sh

uninstall:
	@printf "  $(C_RED)remove$(C_RESET)   %s\n" "$(BIN_LINK)"
	@rm -f $(BIN_LINK)
	@printf "  $(C_RED)remove$(C_RESET)   %s\n" "$(SHARE_DIR)"
	@rm -rf $(SHARE_DIR)
	@printf "  $(C_RED)remove$(C_RESET)   completions\n"
	@rm -f $(BASH_DST) $(FISH_DST) $(FISHFN_DST)
	@printf "$(C_GREEN)uninstalled$(C_RESET) $(C_DIM)$(PREFIX)$(C_RESET)\n"
