#!/usr/bin/env zsh
#
# nx-complete-zsh: Tab completion for `nx`, `pnpm nx`, `pnpm exec nx` and `npx nx`.
# The completion itself is the function _nx in this directory. This file puts the directory on
# fpath, so that compinit registers _nx for `nx`, and wraps the completion of pnpm and npx.
#
# A plugin manager may source this file before or after compinit, and the pnpm completion is often
# registered later in ~/.zshrc. The setup therefore runs once more at the first prompt, when all
# startup files have been read.

# The Zsh Plugin Standard way to find this file, also when a plugin manager evals it.
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

(( ${fpath[(Ie)${0:h}]} )) || fpath=(${0:h} $fpath)
autoload -Uz _nx add-zsh-hook

typeset -gA _nx_runner_completers

# `pnpm nx`, `pnpm exec nx` and `npx nx` complete like `nx`; anything else keeps the completion
# that the command had before the setup below replaced it.
_nx_runner() {
  integer skip=0
  if [[ $words[2] == nx ]]; then
    skip=1
  elif [[ $words[1] == pnpm && $words[2] == exec && $words[3] == nx ]]; then
    skip=2
  fi
  if (( skip && CURRENT > skip + 1 )); then
    shift $skip words
    (( CURRENT -= skip ))
    _nx
    return
  fi

  local completer=$_nx_runner_completers[$words[1]]
  if [[ -n $completer ]]; then
    $completer "$@"
  else
    _default
  fi
}

# Registers _nx and _nx_runner when compinit has run; without the completion system it does nothing.
# Safe to run more than once: a completer that replaced _nx_runner since the last run becomes the
# new original.
_nx_complete_setup() {
  (( $+_comps )) || return 0
  # compinit -C reuses a dump that may be older than this plugin.
  [[ -n ${_comps[nx]-} ]] || compdef _nx nx
  local cmd
  for cmd in pnpm npx; do
    [[ ${_comps[$cmd]-} == _nx_runner ]] && continue
    _nx_runner_completers[$cmd]=${_comps[$cmd]-}
    compdef _nx_runner $cmd
  done
}

_nx_complete_first_prompt() {
  add-zsh-hook -d precmd _nx_complete_first_prompt
  _nx_complete_setup
}

_nx_complete_setup
add-zsh-hook precmd _nx_complete_first_prompt
