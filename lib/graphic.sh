#!/bin/bash
# graphic.sh — terminal (TUI) visualization helpers for slurmctl
#
# Pure-stdin/stdout renderers, decoupled from any data source so the same
# primitives back `slurmctl graphic jobs` (bar chart of task states) and
# `slurmctl graphic gpu` (line graph of GPU util over time), and can be reused
# by any command. Depends only on common.sh (colors) + awk.
#
#   bar_chart   — horizontal bars from "<label> <count> [<colorkey>]" stdin lines
#   line_graph  — ASCII line graph from numeric y-values (stdin, one per line)
#   sparkline   — single-line unicode sparkline from numeric values (stdin)

# Map a color keyword to its escape (falls back to no color).
_graphic_color() {
  case "$1" in
    green)  printf '%s' "$GREEN" ;;
    red)    printf '%s' "$RED" ;;
    yellow) printf '%s' "$YELLOW" ;;
    blue)   printf '%s' "$BLUE" ;;
    cyan)   printf '%s' "$CYAN" ;;
    *)      printf '%s' "" ;;
  esac
}

# Terminal width (cols), with sane fallback.
_graphic_cols() {
  local c="${COLUMNS:-}"
  [ -z "$c" ] && c=$(tput cols 2>/dev/null || echo 80)
  echo "$c"
}

# bar_chart [--width N]
# stdin: one "<label> <count> [<colorkey>]" per line.
# Renders right-padded labels + a proportional bar + the count. Bars scale to
# the largest count (or --max), fitted to the terminal width.
bar_chart() {
  local width max=0
  width=$(_graphic_cols)
  while [ $# -gt 0 ]; do
    case "$1" in
      --width) width="$2"; shift 2 ;;
      --max)   max="$2"; shift 2 ;;
      *)       shift ;;
    esac
  done

  local -a labels counts colors
  local lab cnt col maxlabel=0
  while read -r lab cnt col; do
    [ -z "$lab" ] && continue
    labels+=("$lab"); counts+=("${cnt:-0}"); colors+=("${col:-}")
    [ "${#lab}" -gt "$maxlabel" ] && maxlabel=${#lab}
    [ "${cnt:-0}" -gt "$max" ] 2>/dev/null && max=$cnt
  done
  [ "${#labels[@]}" -eq 0 ] && { printf "${DIM}(no data)${RESET}\n"; return; }
  [ "$max" -le 0 ] && max=1

  local barmax=$(( width - maxlabel - 12 ))
  [ "$barmax" -lt 8 ] && barmax=8

  local i n bar c
  for i in "${!labels[@]}"; do
    n=$(( counts[i] * barmax / max ))
    [ "$n" -lt 0 ] && n=0
    bar=$(printf '%*s' "$n" '' | tr ' ' '#')
    c=$(_graphic_color "${colors[i]}")
    printf "  %-*s ${c}%-*s${RESET} %d\n" "$maxlabel" "${labels[i]}" "$barmax" "$bar" "${counts[i]}"
  done
}

# line_graph [--height N] [--width N] [--title STR] [--color KEY]
# stdin: numeric y-values, one per line (or "<x> <y>" — x is used only for the
# end-of-axis time/index labels). Renders an ASCII line graph with y-axis
# min/max labels and an x-axis.
line_graph() {
  local height=12 width title="" colorkey=""
  width=$(( $(_graphic_cols) - 12 ))
  [ "$width" -lt 20 ] && width=20
  while [ $# -gt 0 ]; do
    case "$1" in
      --height) height="$2"; shift 2 ;;
      --width)  width="$2"; shift 2 ;;
      --title)  title="$2"; shift 2 ;;
      --color)  colorkey="$2"; shift 2 ;;
      *)        shift ;;
    esac
  done
  local color; color=$(_graphic_color "$colorkey")

  [ -n "$title" ] && printf "  ${BOLD}%s${RESET}\n" "$title"

  awk -v H="$height" -v W="$width" -v COL="$color" -v RST="$RESET" '
    {
      if (NF >= 2) { xs[NR]=$1; v=$2+0 } else { xs[NR]=NR; v=$1+0 }
      y[NR]=v
      if (NR==1 || v<mn) mn=v
      if (NR==1 || v>mx) mx=v
      n=NR
    }
    END {
      if (n==0) { print "  (no data)"; exit }
      if (mx==mn) mx=mn+1
      # downsample/expand to W columns by nearest-sample bucketing
      for (c=0;c<W;c++) { idx=int(c*n/W)+1; col[c]=y[idx] }
      # build grid (row 0 = top = max)
      for (r=0;r<H;r++) for (c=0;c<W;c++) g[r,c]=" "
      for (c=0;c<W;c++) {
        row=int((col[c]-mn)/(mx-mn)*(H-1)+0.5)
        g[H-1-row, c]="*"
      }
      for (r=0;r<H;r++) {
        if (r==0)        lab=sprintf("%9.2f", mx)
        else if (r==H-1) lab=sprintf("%9.2f", mn)
        else             lab=sprintf("%9s", "")
        line=lab" |"
        for (c=0;c<W;c++) line=line g[r,c]
        printf "%s%s%s%s\n", substr(line,1,11), COL, substr(line,12), RST
      }
      axis=sprintf("%9s +", "")
      for (c=0;c<W;c++) axis=axis "-"
      print axis
      # x-axis endpoints (first/last x label)
      printf "%11s%-*s%s\n", "", W, xs[1], xs[n]
    }
  '
}

# sparkline: compact single-line unicode graph from numeric stdin values.
sparkline() {
  awk '
    { v[NR]=$1+0; if (NR==1||v[NR]<mn) mn=v[NR]; if (NR==1||v[NR]>mx) mx=v[NR]; n=NR }
    END {
      if (n==0) { print "(no data)"; exit }
      split("▁▂▃▄▅▆▇█", b, "")
      if (mx==mn) mx=mn+1
      out=""
      for (i=1;i<=n;i++) { k=int((v[i]-mn)/(mx-mn)*7+0.5)+1; out=out b[k] }
      print out
    }
  '
}
