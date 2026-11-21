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
  packages = built.packages.${system};

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

  fixtureGoCheck =
    check:
    (goda.mkFlake (
      fixture
      // {
        perSystem = _: { outputs = plugin: { checks.it = plugin.goCheck check; }; };
      }
    )).checks.${system}.it;
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
  layout = import ./layout.nix { inherit pkgs packages; };

  # helptags adds doc/tags to the shipped plugin, and nothing else may differ.
  goda-vim-is-go-mod = fixtureGoCheck {
    name = "goda-vim-is-go-mod";
    script = ''
      resolved=$(go list -m -f '{{.Dir}}' github.com/Shougo/goda.vim)
      diff -rq "$resolved" ${packages.goda-vim} > difference || true
      if [ "$(cat difference)" != "Only in ${packages.goda-vim}/doc: tags" ]; then
        echo "packages.goda-vim is not the goda.vim that go.mod resolves to:" >&2
        cat difference >&2
        exit 1
      fi
    '';
  };
}
// lib.mapAttrs' (name: lib.nameValuePair "fixture-${name}") built.checks.${system}
