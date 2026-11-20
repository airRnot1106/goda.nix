# goda.nix's checks. None of them needs a plugin repository, so a goda.nix
# change is verified before any plugin updates its input.
{
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  goMod = import ../lib/go-mod.nix { inherit lib; };

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
}
