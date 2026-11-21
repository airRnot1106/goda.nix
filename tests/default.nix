{
  nixpkgs,
  system,
  goda,
  exported,
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  goMod = import ../lib/go-mod.nix { inherit lib; };

  fixture = import ./fixture { inherit pkgs; };
  plugin = goda.buildGodaPlugin pkgs fixture;

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

  goTest =
    name: nativeBuildInputs: command:
    plugin.binary.overrideAttrs (prev: {
      name = "goda-fixture-${name}";
      doCheck = true;
      nativeBuildInputs = prev.nativeBuildInputs ++ nativeBuildInputs;
      checkPhase = ''
        runHook preCheck
        export HOME=$TMPDIR
        ${command}
        runHook postCheck
      '';
      installPhase = "touch $out";
    });
in
{
  go-mod = runTests "go-mod" (import ./go-mod.nix { inherit goMod; });
  build-goda-plugin = runTests "build-goda-plugin" (
    import ./build-goda-plugin.nix {
      inherit
        pkgs
        goda
        exported
        fixture
        ;
    }
  );
  nix-update-positions = runTests "nix-update-positions" (
    import ./nix-update.nix { inherit lib plugin; }
  );
  layout = import ./layout.nix { inherit pkgs plugin; };

  fixture-unit = goTest "unit" [ ] "go test ./internal/...";
  fixture-e2e = goTest "e2e" [
    pkgs.vim
    pkgs.neovim
  ] "go test -v -count=1 ./e2e";
}
