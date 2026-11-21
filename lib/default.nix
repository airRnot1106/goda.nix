let
  # x86_64-darwin is absent because nixpkgs 26.11 throws when it evaluates that system.
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  settingNames = [
    "binary"
    "check"
    "outputs"
  ];
in
{
  inherit systems;

  /**
    Flake outputs for one goda plugin.

    mkFlake {
      nixpkgs     # the caller's nixpkgs input. Every derivation comes from its legacyPackages.
      src         # a path (./.) with go.mod and the main package at its root.
      version     # the plugin's version label.
      vendorHash  # SRI hash of the proxyVendor module download, a literal in the caller's flake.nix.
      vimModules  # Go module paths other than goda.vim whose Vim side the plugin needs at runtime.
      perSystem   # { pkgs, system } -> { binary ? { }, check ? { }, outputs ? (plugin -> { }) }
    }

    Invariants:
    - The Vim side of goda.vim and of each module in vimModules is the tree the
      go command extracts from the binary's own module download. No argument
      supplies it from anywhere else, so it cannot differ from what go.mod says.
    - The plugin name and the Go toolchain come from go.mod. No argument
      overrides them.
    - binary and check cannot see the built plugin. Only outputs can.
    - src and version reach the binary with the positions the caller gave
      them, so nix-update edits the caller's file.
    - No attribute name of the result depends on pkgs, so `nix flake show`
      works for a system that the caller's nixpkgs cannot evaluate.

    Returns { packages, checks, devShells } per system, plus whatever outputs
    adds. See plugin.nix for the defaults.
  */
  mkFlake =
    {
      nixpkgs,
      src,
      version,
      vendorHash,
      vimModules ? [ ],
      perSystem ? _: { },
    }@args:
    let
      inherit (nixpkgs) lib;
      goMod = import ./go-mod.nix { inherit lib; };
      plugin = import ./plugin.nix { inherit lib goMod; };

      mod =
        if builtins.isPath src then
          goMod.read src
        else
          throw "goda.nix: src must be a path such as ./. , got a ${builtins.typeOf src}";

      settingsFor =
        system:
        let
          given = perSystem {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          };
          unknown = lib.subtractLists settingNames (builtins.attrNames given);
        in
        if unknown != [ ] then
          throw "goda.nix: perSystem returned ${toString unknown}. It returns only ${toString settingNames}, and extra flake outputs go under outputs."
        else
          {
            binary = { };
            check = { };
            outputs = _: { };
          }
          // given;

      forSystem =
        system:
        let
          settings = settingsFor system;
          built = plugin.build {
            pkgs = nixpkgs.legacyPackages.${system};
            inherit mod vimModules;
            # nix-update edits the file where src and version were written.
            # Taking them from args keeps that the caller's flake.nix.
            # `inherit src version vendorHash` would make it this file.
            pinned = builtins.intersectAttrs {
              src = null;
              version = null;
              vendorHash = null;
            } args;
            inherit (settings) binary check;
          };
        in
        mergeOneLevel built.outputs (settings.outputs built.plugin);

      isGroup = value: builtins.isAttrs value && !lib.isDerivation value;

      mergeOneLevel =
        defaults: extra:
        defaults
        // builtins.mapAttrs (
          name: value:
          if isGroup (defaults.${name} or null) && isGroup value then defaults.${name} // value else value
        ) extra;

      transpose =
        bySystem:
        let
          names = lib.unique (lib.concatMap builtins.attrNames (builtins.attrValues bySystem));
        in
        lib.genAttrs names (
          name:
          lib.mapAttrs (_: outputs: outputs.${name}) (
            lib.filterAttrs (_: outputs: outputs ? ${name}) bySystem
          )
        );
    in
    transpose (lib.genAttrs systems forSystem);
}
