{
  description = "Build a goda.vim plugin flake from a plugin repository, with go.mod as the only pin of goda.vim";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      checks = forAllSystems (system: import ./tests { inherit nixpkgs system; });
    };
}
