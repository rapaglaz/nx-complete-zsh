#!/usr/bin/env bash
#
# Lint and format check, shared by CI, the pre-commit hook and `mise run check`: zsh syntax
# (zsh -n), ShellCheck and shfmt for the Bash scripts. ShellCheck and shfmt do not read zsh, so
# the zsh files get only the syntax check. With --write, shfmt formats the files instead.
#
# Usage: bash scripts/check.sh [--write]

set -uo pipefail

# An empty CDPATH keeps cd from searching it and printing the directory.
CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

zsh_files=(_nx nx-complete-zsh.plugin.zsh tests/*.zsh)
bash_files=(scripts/*.sh tests/*.sh)
# The same style as the rest of the repository: four spaces, indented case branches.
shfmt_flags=(-i 4 -ci)

if [[ "${1:-}" == --write ]]; then
    shfmt "${shfmt_flags[@]}" -w "${bash_files[@]}"
    exit
fi

failed=0

step() {
    local title="$1"
    shift
    echo "==> ${title}"
    if ! "$@"; then
        echo "FAILED: ${title}" >&2
        failed=1
    fi
}

# shellcheck disable=SC2329 # called through step
zsh_syntax() {
    local file status=0
    # zsh -n checks only its first argument, so each file gets its own run.
    for file in "${zsh_files[@]}"; do
        zsh -n "$file" || status=1
    done
    return "$status"
}

step "zsh syntax" zsh_syntax
step "bash syntax" bash -n "${bash_files[@]}"
step "shellcheck" shellcheck -x -S style "${bash_files[@]}"
step "shfmt" shfmt "${shfmt_flags[@]}" -d "${bash_files[@]}"

exit "$failed"
