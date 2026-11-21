{
  description = "Build a goda.vim plugin: the Go binary and the Vim plugin that holds it";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      goda = import ./lib;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      lib = { inherit (goda) buildGodaPlugin; };

      checks = forAllSystems (
        system:
        import ./tests {
          inherit nixpkgs system goda;
          exported = self.lib;
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          fixture = (goda.buildGodaPlugin pkgs (import ./tests/fixture { inherit pkgs; })).binary;
        }
      );
    };
}
