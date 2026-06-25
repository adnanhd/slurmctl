#!/bin/bash
# Bash completion for slurmctl

# Cache partition list for one shell session (sinfo can be slow)
_slurmctl_partitions() {
  if [ -z "${_SLURMCTL_PARTS:-}" ]; then
    _SLURMCTL_PARTS=$(sinfo -h -o '%R' 2>/dev/null | sort -u | tr '\n' ' ')
  fi
  echo "$_SLURMCTL_PARTS"
}

_slurmctl() {
  local cur prev words cword
  _init_completion || return

  local subcommands="submit list status util resubmit cancel throttle
    tail cat head less watch errors
    nodes health usage
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
      -j|--job) ((i++)) ;;
      -*) ;;
      *) cmd="${words[i]}"; break ;;
    esac
  done
  [ -z "$cmd" ] && return

  # Dynamic partition completion for -p/--partition values
  case "$prev" in
    -p|--partition)
      COMPREPLY=($(compgen -W "$(_slurmctl_partitions)" -- "$cur"))
      return
      ;;
  esac

  case "$cmd" in
    submit)
      COMPREPLY=($(compgen -W "--after --wrap --array --output --error" -- "$cur"))
      local scripts
      scripts=$(find . -type f -name '*.slurm' -not -path '*/.*' 2>/dev/null | sed 's|^\./||')
      COMPREPLY+=($(compgen -W "$scripts" -- "$cur"))
      ;;
    list)
      COMPREPLY=($(compgen -W "--summary --failed --completed --running --pending --cancelled --timeout --since --until -v --verbose --sort --visual --graphical -j --job" -- "$cur"))
      ;;
    status)
      COMPREPLY=($(compgen -W "--acct --eff --why --failed --completed --running --pending --cancelled --timeout --node-fail --sort --visual --graphical --task -j --job" -- "$cur"))
      ;;
    resubmit)
      COMPREPLY=($(compgen -W "--failed --cancelled --timeout --node-fail --all --since --until -n --node -p --partition -j --job" -- "$cur"))
      ;;
    cancel)
      COMPREPLY=($(compgen -W "--all --pending --running --since --until -n --node -p --partition -j --job" -- "$cur"))
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
      COMPREPLY=($(compgen -W "-n --all --oneline --script --failed --completed --running --pending --cancelled --timeout --node-fail --since --until" -- "$cur"))
      ;;
    usage)
      COMPREPLY=($(compgen -W "-a --account --all --cluster --gpu --tres -t --start --end" -- "$cur"))
      ;;
    *)
      COMPREPLY=($(compgen -W "-j --job" -- "$cur"))
      ;;
  esac
}

complete -F _slurmctl slurmctl
