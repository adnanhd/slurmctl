#!/bin/bash
# Bash completion for slurmctl

_slurmctl() {
  local cur prev words cword
  _init_completion || return

  local subcommands="submit list status acct tasks running failed resubmit resubmitall
    tail cat head less watch errors cancel cancelall nodes users info
    update history pop clear clean health help failed-list"

  # Complete subcommand as first argument
  if [ "$cword" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"
  case "$cmd" in
    submit)
      # Complete .slurm files and submit-specific flags
      COMPREPLY=($(compgen -W "--after" -- "$cur"))
      COMPREPLY+=($(compgen -f -X '!*.slurm' -- "$cur"))
      ;;
    tail|cat|head|less)
      COMPREPLY=($(compgen -W "--no-out --no-err --job -j" -- "$cur"))
      ;;
    *)
      COMPREPLY=($(compgen -W "--job -j" -- "$cur"))
      ;;
  esac
}

complete -F _slurmctl slurmctl
