# `nix flake show` reads the attribute names of every system and builds
# nothing. A system that nixpkgs refuses to evaluate must still list its names.
{
  lib,
  goda,
  fixture,
}:
let
  unforced = goda.mkFlake (
    fixture
    // {
      nixpkgs = {
        inherit (fixture.nixpkgs) lib;
        legacyPackages = lib.genAttrs goda.systems (system: throw "pkgs of ${system} was forced");
      };
    }
  );
  names = lib.mapAttrs (_: lib.mapAttrs (_: builtins.attrNames)) unforced;
in
{
  testNamesDoNotForcePkgs = {
    expr = builtins.tryEval (builtins.deepSeq names names);
    expected = {
      success = true;
      value = lib.mapAttrs (_: lib.genAttrs goda.systems) {
        packages = _: [
          "default"
          "goda-fixture"
          "goda-vim"
          "vim-plugin"
        ];
        checks = _: [
          "e2e"
          "go-check"
          "runtimepath"
          "unit"
          "vim-plugin"
        ];
        devShells = _: [ "default" ];
      };
    };
  };
}
