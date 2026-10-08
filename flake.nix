{
  description = "herdr-kanban — a kanban board for agent work, as a herdr plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f { pkgs = nixpkgs.legacyPackages.${system}; });

      # Every output that is about the plugin itself is built from these sources
      # with the consumer's (or this flake's) nixpkgs.
      kanbanFor = pkgs: import ./nix/package.nix { inherit pkgs; };
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        let
          kanban = kanbanFor pkgs;
        in
        {
          default = kanban.app;
          inherit (kanban)
            app
            cli
            launcher
            python
            ;
        }
      );

      checks = forAllSystems (
        { pkgs, ... }:
        let
          kanban = kanbanFor pkgs;
        in
        {
          # The board is launched into a herdr pane, so anything broken at import
          # or in the store/render paths shows up as a pane that opens and
          # closes. This runs the packaged app, not the working tree.
          selftest = pkgs.runCommand "herdr-kanban-selftest" { } ''
            export HOME="$TMPDIR"
            ${kanban.cli}/bin/herdr-kanban --selftest
            touch $out
          '';

          # The board protocol is both documentation and a prompt an agent acts
          # on: it lives in the Python source and is quoted in docs/kanban.md,
          # and it has drifted before. This fails when the two disagree.
          protocol-sync = pkgs.runCommand "herdr-kanban-protocol-sync" { } ''
            ${pkgs.bash}/bin/bash ${./scripts/check-kanban-protocol-sync.sh} \
              ${kanban.python}/bin/python ${kanban.app}/share/herdr-kanban ${./docs/kanban.md}
            touch $out
          '';

          # Nix hygiene. `nix flake check` is the gate a contributor can run
          # without installing anything, so formatting and linting live here
          # rather than only in CI.
          formatting = pkgs.runCommand "herdr-kanban-formatting" { } ''
            find ${./.} -name '*.nix' -type f -print0 | while IFS= read -r -d "" file; do
              ${pkgs.nixfmt}/bin/nixfmt --check "$file" || {
                echo "nixfmt: $file is not formatted — run \`nix fmt\`" >&2
                exit 1
              }
            done
            touch $out
          '';

          statix = pkgs.runCommand "herdr-kanban-statix" { } ''
            XDG_CACHE_HOME="$TMPDIR" ${pkgs.statix}/bin/statix check ${./.}
            touch $out
          '';

          deadnix = pkgs.runCommand "herdr-kanban-deadnix" { } ''
            ${pkgs.deadnix}/bin/deadnix --fail ${./.}
            touch $out
          '';
        }
      );

      # `programs.herdr-kanban.*` — deploy the board from a consumer's
      # home-manager config.
      homeModules.default = import ./nix/module.nix;

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
