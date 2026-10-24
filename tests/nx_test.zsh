#!/usr/bin/env zsh
#
# Tests the completion function _nx and the pnpm/npx wrapper in a fake workspace: generator
# options and values from schema.json, target configurations from the project graph, the hand-over
# to NX_COMPLETE and the cache refresh. compadd, compset, _files and _default are replaced by
# functions that print what they get, because the real ones work only inside a completion widget.
#
# Usage: zsh -f tests/nx_test.zsh (or `mise run test`)

REPO_DIR="${0:A:h:h}"
ROOT="$(mktemp -d)"
trap 'rm -rf "${ROOT}"' EXIT
failed=0
WS="$ROOT/ws"

command -v jq >/dev/null || { echo "FAIL jq is missing"; exit 1; }

mkdir -p "$WS/.nx/workspace-data" "$WS/apps/app/src" "$WS/tools/gen" \
  "$WS/node_modules/@acme/plugin/component" "$WS/node_modules/.bin" \
  "$WS/node_modules/nx/dist/src/command-line/completion"
print '{}' >"$WS/nx.json"

write_graph() { # <mtime for touch -t> <configurations of app:build as JSON array>
  cat >"$WS/.nx/workspace-data/project-graph.json" <<EOF
{ "nodes": {
  "app": { "name": "app", "data": { "root": "apps/app", "targets": {
    "build": { "configurations": { $(jq -r 'map("\"\(.)\": {}") | join(", ")' <<<"$2") } },
    "serve": {} } } },
  "lib": { "name": "lib", "data": { "root": "libs/lib", "targets": {
    "build": { "configurations": { "production": {}, "ci": {} } } } } },
  "gen": { "name": "gen", "data": { "root": "tools/gen", "targets": {} } }
} }
EOF
  touch -t "$1" "$WS/.nx/workspace-data/project-graph.json"
}
write_graph 202001010000 '["development", "production"]'

print '{ "name": "@acme/plugin", "generators": "./generators.json" }' \
  >"$WS/node_modules/@acme/plugin/package.json"
print '{ "generators": { "component": { "schema": "./component/schema.json", "aliases": ["c"] } } }' \
  >"$WS/node_modules/@acme/plugin/generators.json"
cat >"$WS/node_modules/@acme/plugin/component/schema.json" <<'EOF'
{ "properties": {
  "style": { "type": "string", "enum": ["css", "scss"], "description": "The\nstyle." },
  "project": { "type": "string", "x-dropdown": "projects" },
  "skipTests": { "type": "boolean" },
  "name": { "type": "string" },
  "secret": { "type": "string", "visible": false }
} }
EOF
# A local plugin: a project of the graph whose package.json names a collection.
print '{ "name": "@local/gen", "schematics": "./collection.json" }' >"$WS/tools/gen/package.json"
print '{ "schematics": { "thing": { "schema": "./thing.json" } } }' >"$WS/tools/gen/collection.json"
print '{ "properties": { "flavor": { "type": "string" } } }' >"$WS/tools/gen/thing.json"

# Fake Nx 23: records what it was called with and answers like NX_COMPLETE does.
cat >"$WS/node_modules/.bin/nx" <<EOF
#!/bin/sh
printf '%s|' "\${NX_COMPLETE:-none}" "\$@" >"$ROOT/nx-call"
printf 'build\tRun build\napp:\n'
EOF
chmod +x "$WS/node_modules/.bin/nx"

# Completion stubs: print the candidates, after resolving the array names that -a and -d take.
compadd() {
  local -a out
  local array=0 opt
  while (( $# )); do
    case $1 in
      -a) array=1 ;;
      -d) shift ;;
      -S) out+=("[S:$2]"); shift ;;
      -l) ;;
      *) if (( array )); then out+=("${(@P)1}"); else out+=("$1"); fi ;;
    esac
    shift
  done
  print -r -- "${out[*]}"
}
compset() { print -r -- "compset $*"; }
_files() { print files; }
_default() { print default; }
_pnpm_original() { print pnpm-original; }
compdef() { local fn=$1 cmd; shift; for cmd; do _comps[$cmd]=$fn; done; }
typeset -gA _comps=(pnpm _pnpm_original)

source "$REPO_DIR/nx-complete-zsh.plugin.zsh"

# Runs a completion function for a command line whose last word is the one under the cursor.
complete_line() { # <function> <words...>
  local fn=$1; shift
  local -a words=("$@")
  local CURRENT=$#words
  $fn
}

check() { # <description> <expected> <actual>
  if [[ $3 == $2 ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1 (expected '$2', got '$3')"
    failed=1
  fi
}

cd "$WS/apps/app/src"

out=$(complete_line _nx nx g @acme/plugin:component --)
check "generator options from schema.json, plus the flags of nx generate" \
  "--style --project --skipTests --name --dry-run --interactive --quiet --verbose --help" "$out"
check "options with visible: false are left out" "" "${(M)out:#*secret*}"
check "enum values after --style=, via an alias of the generator" \
  $'compset -P *=\ncss scss' "$(complete_line _nx nx generate @acme/plugin:c --style=)"
check "x-dropdown projects after --project" "app lib gen" \
  "$(complete_line _nx nx g @acme/plugin:component --project '')"
check "free text value falls back to file names" "files" \
  "$(complete_line _nx nx g @acme/plugin:component --name '')"
check "generator of a local plugin (schematics field)" \
  "--flavor --dry-run --interactive --quiet --verbose --help" \
  "$(complete_line _nx nx g @local/gen:thing --)"

check "nx run project:target:<Tab> lists configurations" $'compset -P *:*:\ndevelopment production' \
  "$(complete_line _nx nx run app:build:)"
check "-c after nx <target> <project>" "ci production" "$(complete_line _nx nx build lib -c '')"
check "--configuration= after nx run" $'compset -P *=\ndevelopment production' \
  "$(complete_line _nx nx run app:build --configuration=)"
check "-c after run-many -t: configurations of all projects" "development production ci" \
  "$(complete_line _nx nx run-many -t build,serve -c '')"

rm -f "$ROOT/nx-call"
check "other positions go to Nx; a value ending in : gets no space" "[S:] build app:" \
  "$(complete_line _nx nx b)"
check "Nx gets NX_COMPLETE=zsh and the words up to the cursor" "zsh|nx|b|" "$(cat "$ROOT/nx-call")"

rm -f "$ROOT/nx-call"
check "nx g <Tab> (generator names) goes to Nx" "[S:] build app:" "$(complete_line _nx nx g '')"
check "Nx sees the generate words" "zsh|nx|g||" "$(cat "$ROOT/nx-call")"

rm -f "$ROOT/nx-call"
check "pnpm nx completes like nx" $'compset -P *:*:\ndevelopment production' \
  "$(complete_line _nx_runner pnpm nx run app:build:)"
check "pnpm exec nx completes like nx" "ci production" \
  "$(complete_line _nx_runner pnpm exec nx build lib -c '')"
check "npx nx completes like nx" "[S:] build app:" "$(complete_line _nx_runner npx nx b)"
check "other pnpm commands keep the pnpm completion" "pnpm-original" \
  "$(complete_line _nx_runner pnpm install '')"
check "pnpm n<Tab> on the nx word itself stays pnpm" "pnpm-original" \
  "$(complete_line _nx_runner pnpm nx)"
check "other npx commands get the default completion" "default" \
  "$(complete_line _nx_runner npx tsc '')"

source "$REPO_DIR/nx-complete-zsh.plugin.zsh"
check "a second source keeps the original pnpm completer" "_pnpm_original" "$_nx_runner_completers[pnpm]"

# Newer graph: the cached configurations are replaced in the same shell.
complete_line _nx nx run app:build: >/dev/null
write_graph 202101010000 '["staging"]'
check "a newer project graph refreshes the cache" $'compset -P *:*:\nstaging' \
  "$(complete_line _nx nx run app:build:)"

rm -rf "$WS/node_modules/nx/dist"
print '{ "name": "nx", "version": "24.0.1", "dependencies": { "x": { "version": "1.0.0" } } }' \
  >"$WS/node_modules/nx/package.json"
check "Nx 24 is recognized by its version when the modules moved" "[S:] build app:" \
  "$(complete_line _nx nx b)"

print '{ "name": "nx", "version": "23.2.9" }' >"$WS/node_modules/nx/package.json"
rm -f "$ROOT/nx-call"
check "an Nx without NX_COMPLETE is not run" "files" "$(complete_line _nx nx build '')"
check "the old Nx binary was not called" "no" "$([[ -e $ROOT/nx-call ]] && echo yes || echo no)"

cd "$ROOT"
check "outside a workspace: default completion" "default" "$(complete_line _nx nx '')"

exit $failed
