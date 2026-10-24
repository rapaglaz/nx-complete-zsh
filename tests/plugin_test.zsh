#!/usr/bin/env zsh
#
# Tests how nx-complete-zsh.plugin.zsh registers the completion with the real compinit: loaded
# before compinit (Oh My Zsh, antidote, zinit), after it, without it, with a stale dump of
# compinit -C, and with a pnpm completion that is registered later in ~/.zshrc. Every case runs in
# its own `zsh -f`, and the first prompt is simulated by calling the precmd hooks.
#
# Usage: zsh -f tests/plugin_test.zsh (or `mise run test`)

REPO_DIR="${0:A:h:h}"
ROOT="$(mktemp -d)"
trap 'rm -rf "${ROOT}"' EXIT
failed=0

# Shared by every case: report the registration in one line, run the precmd hooks.
prelude='
plugin=$1
report() { print -r -- "nx=${_comps[nx]-} pnpm=${_comps[pnpm]-} npx=${_comps[npx]-} orig=${_nx_runner_completers[pnpm]-}"; }
first_prompt() { local f; for f in $precmd_functions; do $f; done; }
_pnpm_late() { :; }
autoload -Uz compinit
'

run_case() { # <script>
  zsh -f -c "$prelude$1" zsh "$REPO_DIR/nx-complete-zsh.plugin.zsh" 2>&1
}

check() { # <description> <expected> <actual>
  if [[ $3 == $2 ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1 (expected '$2', got '$3')"
    failed=1
  fi
}

check "loaded before compinit: compinit finds _nx, the first prompt wraps a late pnpm completion" \
  "nx=_nx pnpm=_nx_runner npx=_nx_runner orig=_pnpm_late" \
  "$(run_case '
    source $plugin
    compinit -u -D
    compdef _pnpm_late pnpm
    first_prompt
    report')"

check "loaded after compinit: registered at once, a later pnpm completion is wrapped again" \
  $'nx=_nx pnpm=_nx_runner npx=_nx_runner orig=\nnx=_nx pnpm=_nx_runner npx=_nx_runner orig=_pnpm_late' \
  "$(run_case '
    compinit -u -D
    source $plugin
    report
    compdef _pnpm_late pnpm
    first_prompt
    report')"

check "the hook runs only at the first prompt" "0" \
  "$(run_case '
    source $plugin
    compinit -u -D
    first_prompt
    print ${#${(M)precmd_functions:#_nx_complete_first_prompt}}')"

check "without compinit: no output and nothing registered" "nx= pnpm= npx= orig=" \
  "$(run_case '
    source $plugin
    first_prompt
    report')"

# A dump written before the plugin was installed: compinit -C does not scan fpath again.
zsh -f -c 'autoload -Uz compinit; compinit -u -d "$1"' zsh "$ROOT/zcompdump" 2>&1
check "compinit -C with a stale dump: the first prompt registers nx" "nx=_nx pnpm=_nx_runner npx=_nx_runner orig=" \
  "$(run_case "
    source \$plugin
    compinit -C -d '$ROOT/zcompdump'
    first_prompt
    report")"

check "a second source keeps the original pnpm completer" "nx=_nx pnpm=_nx_runner npx=_nx_runner orig=_pnpm_late" \
  "$(run_case '
    compinit -u -D
    compdef _pnpm_late pnpm
    source $plugin
    source $plugin
    first_prompt
    report')"

check "the completer of nx is the autoloaded _nx from this repository" "${REPO_DIR}/_nx" \
  "$(run_case '
    source $plugin
    print -r -- ${^fpath}/_nx(N[1])')"

exit $failed
