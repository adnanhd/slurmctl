#!/bin/bash
# Bash completion for slurmctl

_slurmctl() {
  local cur prev words cword
  _init_completion || return

  local subcommands="submit list status resubmit
    tail cat head less watch errors cancel nodes jobs info
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
      if [[ "$prev" == "=" ]] && [[ "${words[*]}" == *--group-by* ]]; then
        COMPREPLY=($(compgen -W "gpu cpu mem job" -- "$cur"))
      elif [[ "$prev" == "--group-by" ]]; then
        COMPREPLY=($(compgen -W "gpu cpu mem job" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "--partition --verbose --group-by" -- "$cur"))
      fi
      ;;
    jobs)
      COMPREPLY=($(compgen -W "--partition" -- "$cur"))
      ;;
    info)
      COMPREPLY=($(compgen -W "--partition --list --raw" -- "$cur"))
      ;;
    status)
      COMPREPLY=($(compgen -W "--acct --eff --why -j --job" -- "$cur"))
      ;;
    list)
      COMPREPLY=($(compgen -W "--summary --failed --completed --running --pending --verbose --sort -j --job" -- "$cur"))
      ;;
    resubmit)
      COMPREPLY=($(compgen -W "--failed --all --node -n --partition -p -j --job" -- "$cur"))
      ;;
    cancel)
      COMPREPLY=($(compgen -W "--all --node -n --partition -p -j --job" -- "$cur"))
      ;;
    *)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
  esac
}

complete -F _slurmctl slurmctl
