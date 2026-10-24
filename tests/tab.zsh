#!/usr/bin/env zsh
#
# Presses Tab in a real interactive zsh on a pseudo terminal (zsh/zpty) and prints `ok` when the
# command line then contains the expected text. Used by tests/smoke.sh, because only the real
# completion widget shows that compinit and the autoloaded _nx work together.
#
# Usage: zsh -f tests/tab.zsh <home> <directory> <typed text> <expected text>

zmodload zsh/zpty zsh/datetime

home=$1 dir=$2 typed=$3 expected=$4
buf=

# Collects the output of the terminal until it matches the pattern or five seconds have passed.
expect() { # <pattern>
  local chunk deadline=$(( EPOCHREALTIME + 5 ))
  while (( EPOCHREALTIME < deadline )); do
    while zpty -r -t shell chunk; do buf+=$chunk; done
    [[ $buf == $~1 ]] && return 0
    sleep 0.1
  done
  return 1
}

# zpty joins its arguments into one command line, so every value is quoted.
zpty shell "env -i HOME=${(q)home} ZDOTDIR=${(q)home} TERM=xterm PATH=${(q)PATH} zsh -i"
# A short prompt and a wide terminal keep the line from wrapping, because ZLE redraws a wrapped
# line in pieces. The marker is split in the typed text, so that only the output of print matches.
zpty -w shell "PROMPT='%# '; stty columns 200; cd ${(q)dir} && print NX_''READY"
if ! expect '*NX_READY*'; then
  print -r -- "no prompt: ${(q+)buf}"
  zpty -d shell
  exit 1
fi

buf=
zpty -w -n shell "$typed"$'\t'
if expect "*${(b)expected}*"; then
  print ok
else
  print -r -- "got: ${(q+)buf}"
fi
zpty -d shell
