#!/usr/bin/env zsh
#
# nx-complete-zsh: Tab completion for `nx`. The completion itself is the function _nx in this
# directory. This file puts the directory on fpath, so that compinit registers _nx for `nx`.
#
# A plugin manager may source this file before or after compinit, and compinit -C may reuse a dump
# that is older than the plugin. The registration therefore runs at once and once more at the
# first prompt, when all startup files have been read.

# The Zsh Plugin Standard way to find this file, also when a plugin manager evals it.
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

(( ${fpath[(Ie)${0:h}]} )) || fpath=(${0:h} $fpath)
autoload -Uz _nx add-zsh-hook

# Registers _nx when compinit has run and has not registered it; without the completion system it
# does nothing.
_nx_complete_setup() {
  (( $+_comps )) || return 0
  [[ -n ${_comps[nx]-} ]] || compdef _nx nx
}

_nx_complete_first_prompt() {
  add-zsh-hook -d precmd _nx_complete_first_prompt
  _nx_complete_setup
}

_nx_complete_setup
add-zsh-hook precmd _nx_complete_first_prompt
