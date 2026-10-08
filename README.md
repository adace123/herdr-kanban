# herdr-kanban

A kanban board for agent work, as a [herdr](https://herdr.dev) plugin.

Every card carries the workspace it belongs to, the agent that should do it, and
the live state of that agent. Dispatch a card and the board starts that agent in
that workspace, prompts it with the task, and mirrors the real agent state
(working / blocked / done) back onto the card — so the board is the plan, and the
panes are the execution.

Cards are stored in `~/.local/state/herdr/plugins/herdr-kanban/board.json` and
belong to you; the plugin never sends them anywhere.

**[docs/kanban.md](docs/kanban.md) is the full manual** — columns, keys, the
dispatch protocol agents are given, worktrees, config reference, and the
internals.

## Install

### Nix (home-manager) — recommended

The plugin ships a home-manager module that builds the board with your own
nixpkgs and deploys it:

```nix
{
  inputs.herdr-kanban.url = "github:adace123/herdr-kanban";

  # in a home-manager module
  imports = [ inputs.herdr-kanban.homeModules.default ];

  programs.herdr-kanban = {
    enable = true;
    # Optional. Defaults to this repo's config.example.toml — the generic keys
    # with no workspace codes, models, or default agent.
    config = ./kanban-config.toml;
  };
}
```

The module copies the manifest and launcher into
`~/.config/herdr/plugins-managed/kanban`, registers it with `herdr plugin link`,
deploys your config to `~/.config/herdr/plugins/config/herdr-kanban/config.toml`,
and adds a `herdr-kanban` CLI. It does **not** write your herdr keybindings —
add those yourself:

```toml
# ~/.config/herdr/config.toml
[[keys.command]]
key = "prefix+k"
type = "plugin_action"
command = "herdr-kanban.open"
description = "kanban board"

[[keys.command]]
key = "ctrl+A"
type = "plugin_action"
command = "herdr-kanban.quick-add"
description = "kanban: capture a task"
```

### Plain herdr plugin

The launcher runs `python3 -m kanban`, so this path needs **Python 3.11+** (for
`tomllib`) with `textual` importable by the `python3` on your `PATH`:

```bash
python3 -m pip install --user 'textual>=8.2'
herdr plugin install adace123/herdr-kanban
```

Or from a checkout:

```bash
git clone https://github.com/adace123/herdr-kanban
herdr plugin link ./herdr-kanban
```

Note that macOS ships Python 3.9 as `python3`; check `python3 --version` first.
A `[[build]]` step that manages its own virtualenv is a planned follow-up.

## Keys

| Key | Action | Opens as |
| --- | --- | --- |
| `prefix+k` | `herdr-kanban.open` — the board | full-pane overlay |
| `ctrl+A` | `herdr-kanban.quick-add` — capture a task | centred popup |

`ctrl+A` is a direct chord, not a prefix, because capture should be one
keystroke; some terminals collapse `ctrl+shift+<letter>` into `ctrl+<letter>`, so
use `prefix+shift+k` instead if it does nothing for you.

The board's own keys, the agent protocol, and the config reference are all in
[docs/kanban.md](docs/kanban.md).

## Config

`config.example.toml` is the generic default. Every key is optional — a missing
file or key falls back to the defaults in `kanban/config.py`. Two tables are
deliberately left to you: `[workspaces]` (the short codes card ids are built
from) and `[models]` (the model names your agents accept).

With Nix, point `programs.herdr-kanban.config` at your file. Without it, write
`~/.config/herdr/plugins/config/herdr-kanban/config.toml` directly.

## Development

```bash
nix flake check --all-systems   # selftest + protocol-sync + formatting
nix build .#cli
./result/bin/herdr-kanban --selftest
./result/bin/herdr-kanban --snapshot --width 200 --height 50   # the board as text
```

`--selftest` is hermetic (no ambient herdr environment, no network, no real board
file) and is the same check CI runs. `--snapshot` renders the board from
`kanban/demo.py` sample data, which is how UI changes are reviewed without a
terminal.

Linting without Nix:

```bash
ruff check .
markdownlint-cli2
```

## Layout

```text
herdr-plugin.toml      # the herdr plugin manifest
launcher.sh            # @PYTHON@ / @APPDIR@ substituted by nix/package.nix
kanban/                # the Python package (Textual TUI + CLI)
config.example.toml    # generic defaults
nix/package.nix        # the store build: app, launcher, CLI, python
nix/module.nix         # programs.herdr-kanban (home-manager)
docs/kanban.md         # the manual
scripts/               # check-kanban-protocol-sync.sh
```

## License

MIT — see [LICENSE](LICENSE).
