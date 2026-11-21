{ lib, plugin }:
let
  callersFile = toString ./fixture/default.nix;
in
{
  testSrcKeepsTheCallersPosition = {
    expr = (builtins.unsafeGetAttrPos "src" plugin.binary).file;
    expected = callersFile;
  };

  testVersionKeepsTheCallersPosition = {
    expr = (builtins.unsafeGetAttrPos "version" plugin.binary).file;
    expected = callersFile;
  };

  testTheCallersFileSpellsTheHashOfGoModules = {
    expr = lib.hasInfix plugin.binary.goModules.outputHash (builtins.readFile ./fixture/default.nix);
    expected = true;
  };
}
