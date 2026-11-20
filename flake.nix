{
  description = "Build a goda.vim plugin flake from a plugin repository, with go.mod as the only pin of goda.vim";

  # Only the self-tests build with this nixpkgs. mkFlake builds with the
  # nixpkgs its caller passes in.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      goda = import ./lib;
      fixture = import ./tests/fixture { inherit nixpkgs; };
      forAllSystems = nixpkgs.lib.genAttrs goda.systems;
    in
    {
      lib = { inherit (goda) mkFlake; };

      checks = forAllSystems (
        system:
        import ./tests {
          inherit
            nixpkgs
            system
            goda
            fixture
            ;
          exported = self.lib;
        }
      );

      # `nix-update --flake fixture --version=skip` targets this package.
      packages = forAllSystems (system: {
        fixture = (goda.mkFlake fixture).packages.${system}.goda-fixture;
      });
    };
}
