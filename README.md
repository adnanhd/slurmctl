# slurmctl

A bash-based SLURM job manager with per-project history tracking, GPU monitoring, and tab completion.

## Install

```sh
make install                # installs to ~/.local
make install PREFIX=/opt    # custom prefix
```

This symlinks `slurmctl` into `PREFIX/bin/` and installs bash/fish completions.

```sh
make uninstall              # remove everything
```

## Usage

```
slurmctl <command> [options...]
slurmctl -j <JOBID> <command> [options...]
```

Must be run from within a git repository (uses `git rev-parse --show-toplevel` for per-project history).

### Job Submitting

```sh
slurmctl submit train.slurm                    # submit and track in history
slurmctl submit train.slurm --array=0-99%8     # array job
slurmctl submit train.slurm --after 12345      # dependency (afterok)
slurmctl submit --wrap="python train.py"       # inline command
```

Git metadata (commit hash, branch, remote) captured automatically. Any extra flags passed to sbatch.

### Job Listing

```sh
slurmctl list                      # your running/pending jobs (squeue)
slurmctl list --summary            # task count by state (array/single/wrap)
slurmctl list --failed             # failed task IDs (comma-separated)
slurmctl list --failed -v          # failed tasks with details
slurmctl list --completed          # completed task IDs
slurmctl list --running            # running task IDs
slurmctl list --pending            # pending task IDs
```

Auto-detects array vs single vs wrap jobs.

### Job Status

```sh
slurmctl status                    # job state, runtime, resources (+ array summary)
slurmctl status --acct             # accounting details (sacct)
slurmctl status --eff              # resource efficiency (CPU, memory, GPU)
slurmctl status --why              # why is this job pending?
```

Falls back to sacct for completed jobs. Shows array task summary for array jobs.

### Job Control

```sh
slurmctl cancel                    # cancel current job
slurmctl cancel --all              # cancel all active project jobs
slurmctl cancel -n kolyoz23        # cancel your jobs on a node
slurmctl cancel -p palamut-cuda    # cancel your jobs on a partition

slurmctl resubmit                  # resubmit failed tasks of current job
slurmctl resubmit --all            # resubmit all failed jobs from history
slurmctl resubmit --all -p PART    # resubmit failed jobs on a partition
slurmctl resubmit --all -n NODE    # resubmit failed jobs on a node
```

### Output Viewing

```sh
slurmctl tail                      # tail stdout + stderr
slurmctl cat                       # full output
slurmctl head                      # first lines
slurmctl less                      # pager
slurmctl watch                     # live tail -f
slurmctl errors                    # recent stderr
```

Add `--no-out` for stderr only, `--no-err` for stdout only.

### Cluster Info

```sh
slurmctl nodes                     # per-node one-liner (sinfo)
slurmctl nodes -v                  # per-node with CPU/GPU/state detail
slurmctl nodes --group-by=gpu      # nodes grouped by free GPU count
slurmctl nodes --group-by=cpu      # nodes grouped by idle CPU count
slurmctl nodes --group-by=mem      # nodes grouped by total memory
slurmctl nodes --group-by=job      # your jobs grouped by node
slurmctl nodes -p kolyoz-cuda      # filter to partition
slurmctl health                    # version, project, cluster connectivity
```

All `--group-by` modes support `-v` for per-node detail within groups.

### History

```sh
slurmctl history                   # submission log (newest first)
slurmctl history -n 5              # last 5 entries
slurmctl history --all             # include archived
slurmctl update                    # refresh states from sacct
slurmctl pop                       # archive current job
slurmctl clear                     # clear all history
slurmctl clean                     # remove output files
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SLURMCTL_LOG_DIR` | `~/.slurm/log` | Output files and per-project history |

History stored per-project at `$SLURMCTL_LOG_DIR/<encoded-project-path>.slurm.log`.

## Project Structure

```
slurmctl                   # main dispatcher (set -euo pipefail)
lib/common.sh              # shared config, colors, JSON helpers
lib/sacct.sh               # sacct parsing utilities
libexec/slurmctl/*.sh      # subcommand implementations
completions/               # bash and fish completions
Makefile                   # install/uninstall with incremental file targets
```
