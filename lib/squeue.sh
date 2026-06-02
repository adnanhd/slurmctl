#!/bin/bash
# squeue.sh — thin API over the `squeue` CLI.
#
# Every squeue invocation in slurmctl goes through one of these wrappers so the
# libexec/ endpoints describe *what* they want ("my jobs", "live pending tasks")
# rather than repeating squeue's flag soup. Wrappers return raw rows; callers
# own presentation (colorizing, headers).

# Your running/pending jobs in the wide listing format used by `slurmctl list`.
squeue_user_jobs() {
  squeue -u "$USER" -o '%.20i %.12P %.40j %.8u %.2t %.10M %.6D %R'
}

# A job's name (first row only).
squeue_job_name() {
  squeue --job "$1" -o '%j' -h 2>/dev/null | head -1
}

# Job IDs of your jobs currently allocated on a node.
squeue_jobs_on_node() {
  squeue -u "$USER" -h -w "$1" -o '%i' 2>/dev/null
}

# Job IDs of your jobs currently in a partition.
squeue_jobs_on_partition() {
  squeue -u "$USER" -h -p "$1" -o '%i' 2>/dev/null
}

# Live task IDs (%A) of a job currently in a given state (PENDING, RUNNING, ...).
# Non-empty only while such tasks still exist; never aborts under `set -e`.
squeue_live_tasks() {
  squeue -j "$1" -h -t "$2" -o '%A' 2>/dev/null || true
}

# Real pending task count for one array job. squeue -r expands the compressed
# array ranges (e.g. 123_[5-44]) that sacct collapses into a single row.
squeue_pending_count() {
  squeue -j "$1" -h -t PD -r -o '%i' 2>/dev/null | grep -c "${1}_" || true
}

# Per-base-job real pending counts for a CSV of array job IDs.
# Emits "<base_jobid> <count>" lines.
squeue_pending_counts_by_job() {
  squeue -j "$1" -h -t PD -r -o '%i' 2>/dev/null \
    | grep -oE '^[0-9]+' | sort | uniq -c | awk '{print $2, $1}'
}
