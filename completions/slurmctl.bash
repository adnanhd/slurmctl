#!/bin/bash
# Bash completion for slurmctl

_slurmctl() {
  local cur prev words cword
  _init_completion || return

  local subcommands="submit list status acct tasks resubmitall
    tail cat head less watch errors cancel cancelall nodes jobs info
    update history pop clear clean health help"

  # Complete subcommand as first argument
  if [ "$cword" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"
  case "$cmd" in
    submit)
      COMPREPLY=($(compgen -W "--after --wrap --array --output --error" -- "$cur"))
      COMPREPLY+=($(compgen -f -X '!*.slurm' -- "$cur"))
      ;;
    history)
      COMPREPLY=($(compgen -W "--all --oneline --script --state" -- "$cur"))
      ;;
    tail|cat|head|less|watch)
      COMPREPLY=($(compgen -W "--no-out --no-err -j --job" -- "$cur"))
      ;;
    errors)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
    nodes)
      COMPREPLY=($(compgen -W "--partition --verbose --jobs --raw" -- "$cur"))
      ;;
    jobs)
      COMPREPLY=($(compgen -W "--partition" -- "$cur"))
      ;;
    info)
      COMPREPLY=($(compgen -W "--partition --list --raw" -- "$cur"))
      ;;
    status)
      COMPREPLY=($(compgen -W "-j --job --eff --why" -- "$cur"))
      ;;
    tasks)
      COMPREPLY=($(compgen -W "--summary --failed --completed --running --pending --list --resubmit --sort -j --job" -- "$cur"))
      ;;
    acct)
      COMPREPLY=($(compgen -W "--format -j --job" -- "$cur"))
      ;;
    cancel)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
    *)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
  esac
}

complete -F _slurmctl slurmctl
