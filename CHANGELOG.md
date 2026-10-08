# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The
version is the one in `herdr-plugin.toml` and `kanban/__init__.py` — they are
kept in step by hand.

## [Unreleased]

## [0.2.0] - 2026-10-07

Extracted from the `nixos-config-v2` repo, where it was a Nix-packaged plugin.
The plugin id, deployed directory, action ids, CLI surface, and board file schema
are all unchanged, so an existing install keeps its settings and its board.

### Added

- `nix/module.nix` — `programs.herdr-kanban`, the home-manager module that
  deploys the manifest, launcher, and config and registers the plugin with
  `herdr plugin link`.
- `flake.nix` — `packages` (app, launcher, CLI, python), `checks` (selftest,
  protocol-sync, formatting, statix, deadnix), and `homeModules.default`.
- `config.example.toml` — the generic defaults. `[workspaces]` and `[models]`
  are left to the consumer.
- `pyproject.toml` (ruff config + `textual` dependency), README, LICENSE, CI,
  and a pre-commit config.

### Changed

- `kanban-package.nix` is now `nix/package.nix`; the manifest and launcher moved
  to the repo root.
- `docs/kanban.md` moved here and now points at herdr.dev and this repo's README
  instead of the consumer's files.
- The self-test and protocol-sync checks are `nix flake check` outputs rather
  than pre-commit hooks in the consumer repo.
