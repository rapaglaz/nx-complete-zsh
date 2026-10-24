#!/usr/bin/env bash
#
# Installs the plugin as an Oh My Zsh custom plugin, the way README.md describes it, into a
# temporary HOME and starts real interactive shells: the start must print nothing, and after the
# first prompt `nx`, `pnpm` and `npx` must have the completers of this plugin, also when a pnpm
# completion is registered after Oh My Zsh in ~/.zshrc. Needs git and network access to clone
# Oh My Zsh (OMZ_REPO selects another source, for example a local clone).
#
# Usage: bash tests/smoke.sh (or `mise run smoke`)

set -euo pipefail

repo_dir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
omz_repo="${OMZ_REPO:-https://github.com/ohmyzsh/ohmyzsh.git}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
failed=0

check() { # <description> <expected> <actual>
    if [[ "$3" == "$2" ]]; then
        echo "ok   $1"
    else
        echo "FAIL $1 (expected '$2', got '$3')"
        failed=1
    fi
}

git clone --quiet --depth 1 "$omz_repo" "$home/.oh-my-zsh"
plugin_dir="$home/.oh-my-zsh/custom/plugins/nx-complete-zsh"
mkdir -p "$plugin_dir"
# The files of a clone of this repository that the shell reads.
cp "$repo_dir/_nx" "$repo_dir/nx-complete-zsh.plugin.zsh" "$plugin_dir/"

cat >"$home/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
zstyle ':omz:update' mode disabled
ZSH_THEME=""
plugins=(git nx-complete-zsh)
source "$ZSH/oh-my-zsh.sh"
# A pnpm completion that is registered after Oh My Zsh, like `pnpm completion zsh` output.
_pnpm_after_omz() { _default; }
compdef _pnpm_after_omz pnpm
EOF

shell() {
    env -i HOME="$home" ZDOTDIR="$home" TERM=dumb PATH="$PATH" zsh "$@"
}

check "a new interactive shell starts without output" "" "$(shell -i -c exit 2>&1)"

# Commands on stdin run after a prompt, so the first-prompt hook has run.
# shellcheck disable=SC2016 # zsh expands the line, not Bash
report="$(printf '%s\n' 'print -r -- "nx=$_comps[nx] pnpm=$_comps[pnpm] npx=$_comps[npx] orig=$_nx_runner_completers[pnpm]"' |
    shell -i 2>/dev/null)"
check "nx, pnpm and npx have the completers of the plugin" \
    "nx=_nx pnpm=_nx_runner npx=_nx_runner orig=_pnpm_after_omz" "$report"

check "Tab stays bound to the Oh My Zsh completion widget" "\"^I\" expand-or-complete" \
    "$(printf '%s\n' "bindkey '^I'" | shell -i 2>/dev/null)"

# A workspace with a fake Nx 23.3 that answers NX_COMPLETE with one target.
ws="$home/ws"
mkdir -p "$ws/apps/app" "$ws/node_modules/.bin" "$ws/node_modules/nx"
echo '{}' >"$ws/nx.json"
echo '{ "name": "nx", "version": "23.3.0" }' >"$ws/node_modules/nx/package.json"
printf '%s\n' '#!/bin/sh' 'printf "build-only\tRun build\n"' >"$ws/node_modules/.bin/nx"
chmod +x "$ws/node_modules/.bin/nx"

check "a real Tab after nx completes from Nx" ok \
    "$(zsh -f "$repo_dir/tests/tab.zsh" "$home" "$ws/apps/app" 'nx bu' 'nx build-only')"
check "a real Tab after pnpm nx completes from Nx" ok \
    "$(zsh -f "$repo_dir/tests/tab.zsh" "$home" "$ws" 'pnpm nx bu' 'pnpm nx build-only')"

exit "$failed"
