# What mkFlake evaluates to. Building is left to the fixture's checks.
{
  lib,
  system,
  goda,
  exported,
  fixture,
}:
let
  fails = value: !(builtins.tryEval (builtins.deepSeq value value)).success;

  plain = removeAttrs fixture [ "perSystem" ];
  withArgs = args: goda.mkFlake (plain // args);
  withSettings = settings: withArgs { perSystem = _: settings; };
  binaryOf = flake: flake.packages.${system}.goda-fixture.drvPath;

  full = goda.mkFlake fixture;
  packages = (withArgs { }).packages.${system};
  checks = (withArgs { }).checks.${system};

  withGodaKs = withArgs { vimModules = [ "github.com/airRnot1106/goda-ks.vim" ]; };
in
{
  testTheFlakeExportsMkFlakeOnly = {
    expr = builtins.attrNames exported;
    expected = [ "mkFlake" ];
  };

  testSystems = {
    expr = builtins.attrNames (withArgs { }).packages;
    expected = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };

  testDefaultPackages = {
    expr = builtins.attrNames packages;
    expected = [
      "default"
      "goda-fixture"
      "goda-vim"
      "vim-plugin"
    ];
  };

  testDefaultChecks = {
    expr = builtins.attrNames checks;
    expected = [
      "e2e"
      "unit"
      "vim-plugin"
    ];
  };

  testToolchainFollowsGoMod = {
    expr = lib.versions.majorMinor packages.goda-fixture.go.version;
    expected = "1.26";
  };

  testChecksShareTheModuleDownload = {
    expr = map (check: check.goModules.drvPath) [
      checks.unit
      checks.e2e
    ];
    expected = [
      packages.goda-fixture.goModules.drvPath
      packages.goda-fixture.goModules.drvPath
    ];
  };

  testE2eGetsTheShippedGodaVim = {
    expr = checks.e2e.drvAttrs.GODA_FIXTURE_E2E_GODA;
    expected = "${packages.goda-vim}";
  };

  testEveryCheckSeesTheContract = {
    expr = checks.unit.drvAttrs.GODA_FIXTURE_E2E_STRICT;
    expected = "1";
  };

  testPluginDependsOnGodaVim = {
    expr = map toString packages.vim-plugin.dependencies;
    expected = [ "${packages.goda-vim}" ];
  };

  testVimModuleIsADependencyAndReachesE2e = {
    expr = withGodaKs.checks.${system}.e2e.drvAttrs.GODA_FIXTURE_E2E_GODA_KS;
    expected = toString (builtins.elemAt withGodaKs.packages.${system}.vim-plugin.dependencies 1);
  };

  testCheckSettingStaysOffTheBinary = {
    expr =
      let
        flake = withSettings {
          check = {
            onlyInChecks = "attribute";
            env.ONLY_IN_CHECKS = "variable";
          };
        };
        seen =
          drv:
          map (name: drv.drvAttrs ? ${name}) [
            "onlyInChecks"
            "ONLY_IN_CHECKS"
          ];
      in
      {
        unit = seen flake.checks.${system}.unit;
        e2e = seen flake.checks.${system}.e2e;
        binary = seen flake.packages.${system}.goda-fixture;
      };
    expected = {
      unit = [
        true
        true
      ];
      e2e = [
        true
        true
      ];
      binary = [
        false
        false
      ];
    };
  };

  testBinarySettingReachesChecks = {
    expr = (withSettings { binary.preBuild = "true"; }).checks.${system}.unit.drvAttrs.preBuild;
    expected = "true";
  };

  testCallerCheckJoinsDefaults = {
    expr =
      builtins.attrNames
        (withSettings {
          outputs = plugin: { checks.extra = plugin.vimPlugin; };
        }).checks.${system};
    expected = [
      "e2e"
      "extra"
      "unit"
      "vim-plugin"
    ];
  };

  testCallerCheckReplacesDefault = {
    expr =
      (withSettings { outputs = plugin: { checks.unit = plugin.vimPlugin; }; })
      .checks.${system}.unit.drvPath;
    expected = packages.vim-plugin.drvPath;
  };

  testDerivationIsALeaf = {
    expr =
      (withSettings { outputs = plugin: { packages.default = plugin.binary; }; })
      .packages.${system}.default.drvPath;
    expected = packages.goda-fixture.drvPath;
  };

  testTopLevelOutputFromCaller = {
    expr =
      builtins.attrNames
        (withSettings { outputs = plugin: { formatter = plugin.binary; }; }).formatter;
    expected = lib.sort lib.lessThan goda.systems;
  };

  testPluginRecord = {
    expr =
      (withSettings { outputs = plugin: { record = builtins.attrNames plugin; }; }).record.${system};
    expected = [
      "binary"
      "devShell"
      "go"
      "goCheck"
      "name"
      "runtimepath"
      "vimPlugin"
    ];
  };

  testRuntimepathIsThePluginThenItsModules = {
    expr = (withSettings { outputs = plugin: { record = plugin.runtimepath; }; }).record.${system};
    expected = "${packages.vim-plugin},${packages.goda-vim}";
  };

  testFixtureChecks = {
    expr = builtins.attrNames full.checks.${system};
    expected = [
      "e2e"
      "go-check"
      "runtimepath"
      "unit"
      "vim-plugin"
    ];
  };

  # Each value would build if goda.nix let it through.
  testBinaryMayNotSetThePin = {
    expr =
      lib.mapAttrs
        (
          name: value:
          fails (
            binaryOf (withSettings {
              binary.${name} = value;
            })
          )
        )
        {
          pname = "other";
          version = "9";
          inherit (fixture) src vendorHash;
          proxyVendor = false;
          goModules = null;
          installPhase = "true";
        };
    expected = {
      pname = true;
      version = true;
      src = true;
      vendorHash = true;
      proxyVendor = true;
      goModules = true;
      installPhase = true;
    };
  };

  testBinaryMayNotSetMainProgram = {
    expr = fails (
      binaryOf (withSettings {
        binary.meta.mainProgram = "other";
      })
    );
    expected = true;
  };

  testBinaryMayAddMeta = {
    expr = {
      inherit
        ((withSettings { binary.meta.description = "fixture"; }).packages.${system}.goda-fixture.meta)
        description
        mainProgram
        ;
    };
    expected = {
      description = "fixture";
      mainProgram = "goda-fixture";
    };
  };

  testCheckMayNotSetWhatACheckIs = {
    expr = map (name: fails (withSettings { check.${name} = null; }).checks.${system}.unit.drvPath) [
      "pname"
      "goModules"
      "doCheck"
      "checkPhase"
      "installPhase"
    ];
    expected = lib.genList (_: true) 5;
  };

  testNoSettingOverridesTheContract = {
    expr = {
      checkStrict =
        fails
          (withSettings { check.env.GODA_FIXTURE_E2E_STRICT = "0"; }).checks.${system}.e2e.drvPath;
      checkModule =
        fails
          (withSettings { check.env.GODA_FIXTURE_E2E_GODA = "/elsewhere"; }).checks.${system}.e2e.drvPath;
      binaryModule = fails (
        binaryOf (withSettings {
          binary.env.GODA_FIXTURE_E2E_GODA = "/elsewhere";
        })
      );
    };
    expected = {
      checkStrict = true;
      checkModule = true;
      binaryModule = true;
    };
  };

  testUnknownSetting = {
    expr = fails (
      binaryOf (withSettings {
        testEnv = { };
      })
    );
    expected = true;
  };

  testSrcMustBeAPath = {
    expr = fails (
      binaryOf (withArgs {
        src = toString fixture.src;
      })
    );
    expected = true;
  };

  testGoVersionMissingFromNixpkgs = {
    expr = fails (withArgs { src = ./cases/go-1-99; }).packages.${system}.goda-case.drvPath;
    expected = true;
  };
}
