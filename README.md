# slurmctl

A bash-based SLURM job manager with a subcommand dispatcher pattern.

## Install

```sh
make install                # installs to ~/.local
make install PREFIX=/opt    # custom prefix
```

This symlinks `slurmctl` into `PREFIX/bin/` and installs bash/fish completions.

To uninstall:

```sh
make uninstall
```

Or run directly from the repo without installing — just add this directory to your `PATH`.

## Usage

```
slurmctl <command> [args...]
```

### Submitting Jobs

```sh
slurmctl submit train.slurm                    # submit a job
slurmctl submit train.slurm --array=0-99       # submit array job
slurmctl submit train.slurm -o logs/%A.out     # custom output path
```

User-specified `-o`/`-e` flags (from CLI args or `#SBATCH` directives in the script) are respected. Defaults to `~/.slurm/%A_%a.{out,err}` if unspecified.

### Job Monitoring

```sh
slurmctl list              # list your running jobs
slurmctl status            # detailed status of current job
slurmctl acct              # job accounting details
```

### Array Jobs

```sh
slurmctl tasks             # show status of all array tasks
slurmctl running           # count running/pending/failed
slurmctl failed            # list failed array task IDs
slurmctl resubmit          # resubmit failed tasks of current job
slurmctl resubmitall       # resubmit all failed jobs in project
```

### Output Viewing

```sh
slurmctl tail              # tail stdout + stderr
slurmctl tail --no-err     # stdout only
slurmctl cat               # cat full output
slurmctl head              # first lines
slurmctl less              # pager
slurmctl watch             # live tail -f
slurmctl errors            # recent stderr
```

### Job Control

```sh
slurmctl cancel            # cancel current job
slurmctl cancelall         # cancel all project jobs
```

### History

```sh
slurmctl update            # refresh states from sacct
slurmctl history           # show submission history
slurmctl pop               # archive job from history
slurmctl clear             # clear all history
slurmctl clean             # remove output files
```

### Global Flags

```sh
slurmctl -j 12345 tail     # target a specific job ID
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SLURMCTL_LOG_DIR` | `~/.slurm` | Directory for output files and per-project history |

History is stored per-project at `$SLURMCTL_LOG_DIR/<encoded-project-path>.slurm.log`, keyed by `git rev-parse --show-toplevel`.

## Project Structure

```
slurmctl                   # main dispatcher
lib/common.sh              # shared config, colors, JSON helpers
lib/sacct.sh               # sacct parsing utilities
libexec/slurmctl/*.sh      # subcommand implementations
completions/               # bash and fish completions
functions/                 # fish wrapper function
Makefile                   # install/uninstall
```
