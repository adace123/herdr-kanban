# home-manager module for the herdr-kanban board plugin.
#
# It owns everything a consumer needs to deploy the board: the packaged app and
# launcher (built with the *consumer's* nixpkgs, so `textual` matches the rest of
# their system), the copied plugin directory, the plugin config, and the
# `herdr plugin link` registration. Consumers keep what is theirs — the herdr
# keybindings and the `config.toml` with their own workspace codes and models.
#
#   programs.herdr-kanban = {
#     enable = true;
#     config = ./kanban-config.toml;   # optional; defaults to config.example.toml
#   };
#
# Deployment shape, kept identical to the hand-written activation this replaces:
# the manifest and launcher are copied into a stable, *real* directory because
# `herdr plugin link` canonicalises the linked path, so a store symlink would go
# stale on every rebuild. The Python app stays in the store and the copied
# launcher bakes in its path.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr-kanban;

  # Built from this repo's sources with the consumer's pkgs.
  kanban = import ./package.nix { inherit pkgs; };

  # An explicit herdr package when one is given; otherwise the activation looks
  # `herdr` up on PATH and falls back to the common user-local install path.
  herdrBin = if cfg.herdrPackage != null then lib.getExe cfg.herdrPackage else null;
in
{
  options.programs.herdr-kanban = {
    enable = lib.mkEnableOption "the herdr-kanban board plugin";

    config = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      defaultText = lib.literalExpression "config.example.toml";
      description = ''
        Plugin configuration deployed to
        `~/.config/herdr/plugins/config/herdr-kanban/config.toml`. Defaults to
        the repo's `config.example.toml` — the generic keys with no workspace
        codes, models, or default agent.
      '';
    };

    pluginDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.config/herdr/plugins-managed/kanban";
      description = ''
        Directory the manifest and launcher are copied into and registered with
        `herdr plugin link`. Must stay a real directory, not a store symlink.
      '';
    };

    herdrPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        The herdr package to register the plugin with. When null, `herdr` is
        looked up on PATH and falls back to `~/.local/bin/herdr`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ kanban.cli ];

    home.activation.herdrKanbanPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      kanbanDir="${cfg.pluginDir}"
      mkdir -p "$kanbanDir"
      cp -f "${kanban.manifest}" "$kanbanDir/herdr-plugin.toml"
      cp -f "${kanban.launcher}" "$kanbanDir/launcher.sh"
      chmod +x "$kanbanDir/launcher.sh"

      # Repo-managed defaults (columns, placement, icon mode, sync cadence) go to
      # the plugin config dir on every activation: the config file is the source
      # of truth. The board stores its tasks in
      # ~/.local/state/herdr/plugins/herdr-kanban/board.json instead, so a
      # deploy never touches them.
      kanbanCfg="$HOME/.config/herdr/plugins/config/herdr-kanban"
      mkdir -p "$kanbanCfg"
      cp -f "${if cfg.config != null then cfg.config else kanban.defaultConfig}" "$kanbanCfg/config.toml"

      ${
        if cfg.herdrPackage != null then
          "herdrBin=${herdrBin}"
        else
          ''
            herdrBin="$(command -v herdr 2>/dev/null || true)"
            [ -x "$herdrBin" ] || herdrBin="$HOME/.local/bin/herdr"''
      }
      if [ -x "$herdrBin" ]; then
        if ! "$herdrBin" plugin list 2>/dev/null | grep -q "herdr-kanban"; then
          "$herdrBin" plugin link "$kanbanDir" >/dev/null 2>&1 || true
        fi
        # Apply the consumer's keybindings to the running server.
        "$herdrBin" server reload-config >/dev/null 2>&1 || true

        # Restart the background reconciler (the plugin's [[startup]] hook runs
        # it when herdr starts) so it runs the code and config just deployed.
        # Only while herdr is up: with no server there is nothing to follow, and
        # the next server start brings it up anyway.
        # The stop goes through the daemon's own lock, not a raw pid file: a pid
        # a crashed daemon left behind names whatever process has it now.
        HERDR_BIN_PATH="$herdrBin" bash "$kanbanDir/launcher.sh" sync-stop >/dev/null 2>&1 || true
        if "$herdrBin" workspace list >/dev/null 2>&1; then
          HERDR_BIN_PATH="$herdrBin" bash "$kanbanDir/launcher.sh" sync >/dev/null 2>&1 || true
        fi
      fi
    '';
  };
}
