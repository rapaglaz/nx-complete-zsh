#!/usr/bin/env bash
#
# Runs the unit tests (tests/*_test.zsh) with the zsh on PATH, or with an older zsh from the
# zshusers/zsh Docker image when a version is given, so that the oldest supported release is
# tested. The image has no jq; the Linux build of jq is mounted into it.
#
# Usage: bash scripts/test.sh [zsh version, for example 5.1]

set -euo pipefail

# An empty CDPATH keeps cd from searching it and printing the directory.
CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.."

zsh_version="${1:-}"
jq_version=1.8.2

if [[ -z "$zsh_version" ]]; then
    failed=0
    for test in tests/*_test.zsh; do
        echo "==> $test ($(zsh --version))"
        zsh -f "$test" || failed=1
    done
    exit "$failed"
fi

# The Linux jq: the one on PATH on Linux, a downloaded release build elsewhere.
if [[ "$(uname -s)" == Linux ]]; then
    jq_bin="$(command -v jq)"
else
    jq_bin="${XDG_CACHE_HOME:-$HOME/.cache}/nx-complete-zsh/jq-$jq_version-linux-amd64"
    if [[ ! -x "$jq_bin" ]]; then
        mkdir -p "$(dirname "$jq_bin")"
        curl -fsSL -o "$jq_bin" \
            "https://github.com/jqlang/jq/releases/download/jq-$jq_version/jq-linux-amd64"
        chmod +x "$jq_bin"
    fi
fi

docker run --rm --platform linux/amd64 \
    -v "$PWD:/repo:ro" -v "$jq_bin:/usr/local/bin/jq:ro" -w /repo \
    "zshusers/zsh:$zsh_version" \
    sh -c 'status=0; for test in tests/*_test.zsh; do echo "==> $test ($(zsh --version))"; zsh -f "$test" || status=1; done; exit $status'
