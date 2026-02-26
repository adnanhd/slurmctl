PREFIX ?= $(HOME)/.local

SHARE_DIR  = $(PREFIX)/share/slurmctl
BIN_DIR    = $(PREFIX)/bin
BASH_COMP  = $(PREFIX)/share/bash-completion/completions
FISH_COMP  = $(PREFIX)/share/fish/vendor_completions.d
FISH_FUNC  = $(PREFIX)/share/fish/vendor_functions.d

.PHONY: install uninstall

install:
	mkdir -p $(SHARE_DIR) $(BIN_DIR) $(BASH_COMP) $(FISH_COMP) $(FISH_FUNC)
	cp -r lib libexec slurmctl $(SHARE_DIR)/
	chmod +x $(SHARE_DIR)/slurmctl
	ln -sf $(SHARE_DIR)/slurmctl $(BIN_DIR)/slurmctl
	cp completions/slurmctl.bash $(BASH_COMP)/slurmctl
	cp completions/slurmctl.fish $(FISH_COMP)/slurmctl.fish
	cp functions/slurmctl.fish $(FISH_FUNC)/slurmctl.fish
	@echo "Installed to $(PREFIX)"

uninstall:
	rm -f $(BIN_DIR)/slurmctl
	rm -rf $(SHARE_DIR)
	rm -f $(BASH_COMP)/slurmctl
	rm -f $(FISH_COMP)/slurmctl.fish
	rm -f $(FISH_FUNC)/slurmctl.fish
	@echo "Uninstalled from $(PREFIX)"
