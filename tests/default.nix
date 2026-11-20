# goda.nix's checks. None of them needs a plugin repository, so a goda.nix
# change is verified before any plugin updates its input.
{
  nixpkgs,
  system,
  goda,
  exported,
  fixture,
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  goMod = import ../lib/go-mod.nix { inherit lib; };

  built = goda.mkFlake fixture;

  runTests =
    name: tests:
    pkgs.runCommand "goda-nix-${name}"
      {
        # A failure that quotes a drvPath would carry its context, and this
        # report would then wait for that derivation's whole build closure.
        failures = builtins.unsafeDiscardStringContext (builtins.toJSON (lib.runTests tests));
      }
      ''
        if [ "$failures" != "[]" ]; then
          echo "$failures" >&2
          exit 1
        fi
        touch $out
      '';
in
{
  go-mod = runTests "go-mod" (import ./go-mod.nix { inherit goMod; });
  mk-flake = runTests "mk-flake" (
    import ./mk-flake.nix {
      inherit
        lib
        system
        goda
        exported
        fixture
        ;
    }
  );
  lazy-names = runTests "lazy-names" (import ./lazy-names.nix { inherit lib goda fixture; });
  nix-update-positions = runTests "nix-update-positions" (
    import ./nix-update.nix {
      inherit
        lib
        system
        goda
        fixture
        ;
    }
  );
}
// lib.mapAttrs' (name: lib.nameValuePair "fixture-${name}") built.checks.${system}
