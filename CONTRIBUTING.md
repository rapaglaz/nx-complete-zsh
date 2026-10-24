# Contributing to nx-complete-zsh

Issues and pull requests are welcome. `main` accepts changes only through pull requests with green CI and signed commits.

## Setup

The development tools are pinned in `mise.toml`. zsh comes from the system (macOS) or the `zsh` package (Linux), because mise does not provide it.

```sh
mise install
mise run hooks       # pre-commit: check and test; commit-msg: Conventional Commits
```

## Checks and tests

```sh
mise run check       # zsh -n, ShellCheck, shfmt
mise run test        # unit tests with the zsh on PATH
mise run test:oldest # unit tests with zsh 5.1 in Docker (CI: at every release)
mise run smoke       # Oh My Zsh in a temporary HOME, a real Tab through zsh/zpty
mise run format      # shfmt
```

CI runs `check`, `test` and `smoke` on ubuntu and macOS for every pull request. The tests with the oldest supported zsh run in the Release workflow.

## Files

| File | Content |
| --- | --- |
| `_nx` | the completion function (`#compdef nx`) |
| `nx-complete-zsh.plugin.zsh` | adds the directory to `fpath` and registers `_nx` |
| `tests/nx_test.zsh` | `_nx` in a fake workspace with a fake Nx, `compadd` replaced by a stub |
| `tests/plugin_test.zsh` | the registration with the real `compinit`: before, after, without, `compinit -C` |
| `tests/smoke.sh`, `tests/tab.zsh` | Oh My Zsh installation and a real Tab |

## Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`), with a subject of at most 72 characters. Mark a breaking change with `!` and a `BREAKING CHANGE:` footer; [Versioning](README.md#versioning) in the README says what counts as breaking.

## Releases

A release takes two steps, because `main` accepts changes only through pull requests:

1. On an up-to-date `main`, run `mise run test:oldest` and then `mise run release:prepare`. git-cliff computes the next version (or pass one, for example `mise run release:prepare v0.2.0`) and writes CHANGELOG.md on the branch `chore/release-vX.Y.Z`; the task commits it, pushes the branch and opens a pull request.
2. After the pull request is merged, run `git switch main && git pull --ff-only && mise run release:tag`. The task creates the signed tag on the release commit and pushes it. The Release workflow then tests the oldest supported zsh and, when the tests pass, creates the GitHub Release with the notes of that version. A failure there leaves the tag without a GitHub Release, and the fix needs a new patch version.

```sh
mise run release:prepare # on main: CHANGELOG.md on a release branch and a pull request
mise run release:tag     # on main after that merge: the signed tag vX.Y.Z
```
