#!/bin/bash
# Bash completion for slurmctl

_slurmctl() {
  local cur prev words cword
  _init_completion || return

  local subcommands="submit list status resubmit cancel
    tail cat head less watch errors
    nodes health
    history update pop clear clean
    help"

  # -j/--job can appear before subcommand
  if [ "$cword" -eq 1 ] || { [ "$cword" -eq 3 ] && [[ "${words[1]}" == -j || "${words[1]}" == --job ]]; }; then
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
    return
  fi

  # Find the actual subcommand (skip -j JOBID prefix)
  local cmd=""
  for ((i=1; i<cword; i++)); do
    case "${words[i]}" in
      -j|--job) ((i++)) ;;  # skip -j and its argument
      -*) ;;
      *) cmd="${words[i]}"; break ;;
    esac
  done
  [ -z "$cmd" ] && return

  case "$cmd" in
    submit)
      COMPREPLY=($(compgen -W "--after --wrap --array --output --error" -- "$cur"))
      COMPREPLY+=($(compgen -f -X '!*.slurm' -- "$cur"))
      ;;
    list)
      COMPREPLY=($(compgen -W "--summary --failed --completed --running --pending -v --verbose --sort -j --job" -- "$cur"))
      ;;
    status)
      COMPREPLY=($(compgen -W "--acct --eff --why -j --job" -- "$cur"))
      ;;
    resubmit)
      COMPREPLY=($(compgen -W "--failed --all -n --node -p --partition -j --job" -- "$cur"))
      ;;
    cancel)
      COMPREPLY=($(compgen -W "--all -n --node -p --partition -j --job" -- "$cur"))
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
        COMPREPLY=($(compgen -W "-v --verbose -p --partition --group-by" -- "$cur"))
      fi
      ;;
    history)
      COMPREPLY=($(compgen -W "-n --all --oneline --script --state" -- "$cur"))
      ;;
    *)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
  esac
}

complete -F _slurmctl slurmctl
