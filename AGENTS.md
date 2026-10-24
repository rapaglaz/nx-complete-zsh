# Instructions for AI coding agents

Tab completion for `nx` in zsh, published as a plugin for Oh My Zsh, antidote, zinit and sheldon. `README.md` describes what the plugin completes and how it works; `CONTRIBUTING.md` has the setup, the tasks and the release steps; this file covers how to change it safely. The plugin runs on every Tab in other people's shells, so a mistake breaks their completion or, worse, runs an Nx command.

## Commands

- `mise run check` runs `zsh -n` on the zsh files and ShellCheck (0.11.0, pinned) and shfmt on the Bash scripts. The pre-commit hook runs it together with `mise run test`.
- `mise run test` runs `tests/*_test.zsh` with the zsh on `PATH`; run one file with `zsh -f tests/<name>_test.zsh` while iterating.
- `mise run test:oldest` runs the same tests with zsh 5.1 in the `zshusers/zsh` Docker image. Run it after a change to `_nx` or the plugin file, because CI runs it only at a release.
- `mise run smoke` installs the plugin as an Oh My Zsh plugin in a temporary `HOME` and presses a real Tab through `zsh/zpty` (needs network). Run it after a change to the registration or to anything that starts a shell.

## Scope

- The plugin completes the command `nx` only. It does not wrap `pnpm`, `npx` or other runners: since 0.2.0 that belongs in the shell configuration, which hands the shifted words to `_normal`, and `_nx` works there because it reads `$words`. Do not add runner handling back.
- `_nx` holds the whole completion and is autoloaded through `#compdef nx`; `nx-complete-zsh.plugin.zsh` only puts the directory on `fpath` and registers `_nx` (at once and at the first prompt, for a stale dump of `compinit -C`). Keep `_nx` in the root of the repository: Oh My Zsh puts that directory on `fpath` before `compinit`.
- Public names are `_nx` and `nx-complete-zsh.plugin.zsh`. Renaming or removing them, raising a minimum version (zsh 5.1, Nx 23.3, jq) or changing the installation is a breaking change (`!` and a `BREAKING CHANGE:` footer). Other `_nx_*` names are internal.

## Conventions

- Comments, names, commit messages, README and PR text are in English. Comments explain why, not what.
- `_nx` and the plugin file use 2-space indent; Bash scripts under `scripts/` and `tests/` use 4 spaces (`shfmt -i 4 -ci`).
- Conventional Commits with `feat`, `fix`, `chore`, `refactor`, `test`, `docs` and `ci`, subject at most 72 characters; the `commit-msg` hook checks it. Commits and tags are GPG-signed.
- Do not add lint rules, plugins or MCP servers without asking.

## Git workflow

- Branch `type/short-description` -> commit -> pull request. `main` accepts only pull requests with green CI and signed commits; never push to it or force-push it.
- Releases go through `mise run release:prepare` and, after that pull request is merged, `mise run release:tag` (see `CONTRIBUTING.md`).
- Pushing, opening a pull request and creating a release are visible to others: confirm with the owner first unless the task already asked for it. Check that a pull request is still open before pushing to its branch; a push to the branch of a merged pull request creates the deleted branch again.

## Things that are easy to get wrong

- An Nx older than 23.3 ignores `NX_COMPLETE` and would run the command that is being typed (`nx run app:build` would build). `_nx_has_native_completion` reads the version from `node_modules/nx/package.json` without starting Node; never call an Nx binary before that check passes, and never take `nx` from `PATH` instead of the workspace.
- `$'\t'` is not expanded inside an associative array subscript, so keys use `$_nx_sep`.
- `zsh -n` evaluates `$(<file)` while it checks the syntax; tests read files with `$(cat ...)`.
- The test stubs of `compadd` resolve array names with `(P)`, so a local variable of the stub with the same name as one of `_nx` (`displays`, `values`, `out`) hides it. Give stub variables names that `_nx` does not use.
- zsh remembers where it found a command; after creating a fake binary that shadows a real one, a test needs `rehash`.
- `zpty` joins its arguments into one command line: quote every value with `${(q)...}` (a `PATH` with a space breaks otherwise). Use `TERM=xterm`, because `TERM=dumb` disables ZLE, and a short prompt with a wide terminal, because ZLE redraws a wrapped line in pieces.
- A new interactive shell must start without any output, and the plugin must not bind keys.
- On the Ubuntu runner `/usr/share/zsh` is writable for everyone, so `compaudit` of Oh My Zsh refuses the system completion functions; the smoke job fixes the permissions first.
