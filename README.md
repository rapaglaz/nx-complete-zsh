# nx-complete-zsh

Tab completion for [Nx](https://nx.dev) in zsh: `nx`, also from a subdirectory of the workspace. Commands, projects, targets and generator names come from the Nx of the workspace. The plugin adds the options of generators with their values and the configurations of targets, which Nx does not complete.

For fish, see [nx-complete-fish](https://github.com/rapaglaz/nx-complete-fish).

## What it completes

| You type | You get | Source |
| --- | --- | --- |
| `nx <Tab>` | commands and targets | Nx (`NX_COMPLETE`) |
| `nx build <Tab>`, `nx run <Tab>` | projects, `project:target` | Nx |
| `nx g <Tab>` | generators, for example `@nx/angular:component` | Nx |
| `nx g @nx/angular:component --<Tab>` | the options of the generator, with descriptions | `schema.json` of the generator |
| `nx g @nx/angular:component --style=<Tab>` | `css`, `scss`, `sass`, `less`, `none` | `enum` in `schema.json` |
| `nx g @nx/workspace:move --projectName <Tab>` | the projects of the workspace | `x-dropdown: projects` |
| `nx run app:build:<Tab>` | `app:build:production`, `app:build:development` | project graph |
| `nx build app -c <Tab>`, `--configuration=<Tab>` | the configurations of the target | project graph |
| `nx run-many -t build,test -c <Tab>` | the configurations of these targets in all projects | project graph |

Outside an Nx workspace, `nx <Tab>` completes file names.

The plugin completes the command `nx` only, like the completion script of Nx itself. Put `node_modules/.bin` of the workspace on `PATH` (see [Troubleshooting](#troubleshooting)), so that `nx` runs and completes directly. Since 0.2.0 the plugin does not wrap `pnpm` and `npx` any more; `pnpm exec nx` and `npx nx` complete when the shell configuration hands the words after the runner to `_normal`, which then calls `_nx`.

## Requirements

- zsh 5.1 or later (tested with 5.9 in every CI run, and with 5.1 before every release)
- Nx 23.3 or later in the workspace (tested with 23.3.0 and 23.3.1). An older Nx gets file names only, see [How it works](#how-it-works).
- [jq](https://jqlang.org) for the generator options and the configurations
- The zsh completion system (`compinit`). Every plugin manager below runs it, or you run it in `~/.zshrc`.

## Installation

The plugin can be loaded before or after `compinit`.

### Oh My Zsh

```sh
git clone https://github.com/rapaglaz/nx-complete-zsh "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/nx-complete-zsh"
```

Add the plugin to the list in `~/.zshrc`:

```zsh
plugins=(... nx-complete-zsh)
```

### antidote

Add this line to `~/.zsh_plugins.txt`:

```text
rapaglaz/nx-complete-zsh
```

### zinit

```zsh
zinit light rapaglaz/nx-complete-zsh
```

### sheldon

```sh
sheldon add nx-complete-zsh --github rapaglaz/nx-complete-zsh
```

### Manual

```sh
git clone https://github.com/rapaglaz/nx-complete-zsh ~/.zsh/nx-complete-zsh
```

Add this line to `~/.zshrc`, before or after `compinit`:

```zsh
source ~/.zsh/nx-complete-zsh/nx-complete-zsh.plugin.zsh
```

The installation as an Oh My Zsh plugin is tested in CI. The lines for antidote, zinit and sheldon follow the documentation of these tools (checked on 2026-10-24).

Remove other Nx completions, for example the `nx-completion` plugin, because only the last completion that is registered for `nx` is used.

## How it works

- Nx 23.3 and later complete commands, projects, targets and generator names themselves. On Tab, the plugin runs the Nx of the workspace (`node_modules/.bin/nx` or `.nx/installation/node_modules/.bin/nx`) with `NX_COMPLETE=zsh` and shows its answer.
- Before that, the plugin reads the version from `node_modules/nx/package.json` (or looks for `nx/dist/src/command-line/completion`) without starting Node. An older Nx is never started, because it ignores `NX_COMPLETE` and would run the command that you are typing: `nx run app:build` would really build.
- Generator options and their values come from the `schema.json` of the generator: `enum` and `items.enum`, booleans, `x-dropdown: projects`, generator aliases, and local workspace plugins through the `generators` or `schematics` field of their `package.json`. Options with `visible: false` are left out.
- Target configurations come from `.nx/workspace-data/project-graph.json`, which every `nx` command writes.
- Both files are read with `jq`, kept in memory and read again when their modification time changes.
- `_nx` is loaded at the first Tab, so a new shell does not pay for it.

## Troubleshooting

- **No projects or configurations.** The project graph does not exist yet, for example in a fresh clone. Run any `nx` command once, for example `pnpm nx show projects`.
- **Only file names after `nx`.** The Nx of the workspace is older than 23.3, or `node_modules` is not installed.
- **`nx <Tab>` does nothing after the installation.** `compinit -C` may reuse an old dump. Open a new shell; if that does not help, delete `~/.zcompdump*` and open a new shell.
- **`nx` is not found.** Nx is usually a dependency of the workspace, not a global command. Put `node_modules/.bin` on `PATH`, for example with [mise](https://mise.jdx.dev) in the `mise.toml` of the workspace:

  ```toml
  [env]
  _.path = ["{{config_root}}/node_modules/.bin"]
  ```

## Development

The development tools are pinned in `mise.toml`. zsh comes from the system (macOS) or the `zsh` package (Linux), because mise does not provide it.

```sh
mise install
mise run hooks       # pre-commit: check and test; commit-msg: Conventional Commits
mise run check       # zsh -n, ShellCheck, shfmt
mise run test        # unit tests with the zsh on PATH
mise run test:oldest # unit tests with zsh 5.1 in Docker (CI: at every release)
mise run smoke       # Oh My Zsh in a temporary HOME, a real Tab through zsh/zpty
mise run format      # shfmt
mise run release:prepare # on main: CHANGELOG.md on a release branch and a pull request
mise run release:tag     # on main after that merge: the signed tag vX.Y.Z
```

| File | Content |
| --- | --- |
| `_nx` | the completion function (`#compdef nx`) |
| `nx-complete-zsh.plugin.zsh` | adds the directory to `fpath` and registers `_nx` |
| `tests/nx_test.zsh` | `_nx` in a fake workspace with a fake Nx, `compadd` replaced by a stub |
| `tests/plugin_test.zsh` | the registration with the real `compinit`: before, after, without, `compinit -C` |
| `tests/smoke.sh`, `tests/tab.zsh` | Oh My Zsh installation and a real Tab |

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`), with a subject of at most 72 characters.

A release takes two steps, because `main` accepts changes only through pull requests:

1. On an up-to-date `main`, run `mise run test:oldest` and then `mise run release:prepare`. git-cliff computes the next version (or pass one, for example `mise run release:prepare v0.2.0`) and writes CHANGELOG.md on the branch `chore/release-vX.Y.Z`; the task commits it, pushes the branch and opens a pull request.
2. After the pull request is merged, run `git switch main && git pull --ff-only && mise run release:tag`. The task creates the signed tag on the release commit and pushes it. The Release workflow then tests the oldest supported shell release and, when the tests pass, creates the GitHub Release with the notes of that version. A failure there leaves the tag without a GitHub Release, and the fix needs a new patch version.

## Versioning

Releases are Git tags `vX.Y.Z` that follow [Semantic Versioning](https://semver.org), with the changes in [CHANGELOG.md](CHANGELOG.md). While the version is 0.x, a breaking change raises the minor version. To stay on one version, check out its tag in the clone, for example `git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/nx-complete-zsh" checkout v0.1.0`.

A change is breaking when it raises a minimum version (Nx, the shell or jq), changes how the plugin is installed, or renames or removes the function `_nx` or the file `nx-complete-zsh.plugin.zsh`. Other names that start with `_nx_`, for example the caches, are internal and can change in any release.

## License

[MIT](LICENSE)
