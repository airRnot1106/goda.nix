{
  pkgs,
  goda,
  exported,
  fixture,
}:
let
  fails = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
  build = args: goda.buildGodaPlugin pkgs (fixture // args);
  binaryOf = args: (build args).binary;
in
{
  testTheFlakeExportsBuildGodaPluginOnly = {
    expr = builtins.attrNames exported;
    expected = [ "buildGodaPlugin" ];
  };

  testNamesFollowGoMod = {
    expr = {
      plugin = (build { }).pname;
      binary = (binaryOf { }).pname;
      inherit ((binaryOf { }).meta) mainProgram;
    };
    expected = {
      plugin = "goda-fixture.vim";
      binary = "goda-fixture";
      mainProgram = "goda-fixture";
    };
  };

  testToolchainFollowsGoMod = {
    expr = (binaryOf { }).go.drvPath;
    expected = pkgs.go_1_26.drvPath;
  };

  testTheModuleDownloadHoldsWholeModules = {
    expr = (binaryOf { }).proxyVendor;
    expected = true;
  };

  testOtherAttributesReachBuildGoModule = {
    expr = (binaryOf { preBuild = "echo fixture"; }).preBuild;
    expected = "echo fixture";
  };

  testCallerMayNotSetWhatGodaNixOwns = {
    expr = builtins.mapAttrs (name: value: fails (binaryOf { ${name} = value; }).drvPath) {
      pname = "other";
      proxyVendor = false;
      installPhase = "true";
      meta.mainProgram = "other";
    };
    expected = {
      pname = true;
      proxyVendor = true;
      installPhase = true;
      meta = true;
    };
  };

  testCallerMayAddMeta = {
    expr = (binaryOf { meta.description = "fixture"; }).meta.description;
    expected = "fixture";
  };

  testSrcMustBeAPath = {
    expr = fails (binaryOf { src = toString fixture.src; }).drvPath;
    expected = true;
  };

  testGoVersionMissingFromNixpkgs = {
    expr = fails (binaryOf { src = ./cases/go-1-99; }).drvPath;
    expected = true;
  };
}
