{
  lib,
  system,
  goda,
  fixture,
}:
let
  binary = (goda.mkFlake fixture).packages.${system}.goda-fixture;
  callersFile = toString ./fixture/default.nix;
in
{
  testSrcKeepsTheCallersPosition = {
    expr = (builtins.unsafeGetAttrPos "src" binary).file;
    expected = callersFile;
  };

  testVersionKeepsTheCallersPosition = {
    expr = (builtins.unsafeGetAttrPos "version" binary).file;
    expected = callersFile;
  };

  testTheCallersFileSpellsTheHashOfGoModules = {
    expr = lib.hasInfix binary.goModules.outputHash (builtins.readFile ./fixture/default.nix);
    expected = true;
  };
}
