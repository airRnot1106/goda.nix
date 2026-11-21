{ goMod }:
let
  fails = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
in
{
  testModuleAndGo = {
    expr = goMod.moduleAndGoLines ''
      module github.com/airRnot1106/goda-ks.vim

      go 1.26

      require github.com/Shougo/goda.vim v0.7.2
    '';
    expected = {
      module = "github.com/airRnot1106/goda-ks.vim";
      go = "1.26";
    };
  };

  testRequireBlockIsIgnored = {
    expr = goMod.moduleAndGoLines ''
      module github.com/airRnot1106/goda-wakachi.vim

      go 1.26

      require (
      	github.com/Shougo/goda.vim v0.9.0
      	github.com/ikawaha/kagome/v2 v2.11.1
      )

      require github.com/ikawaha/kagome-dict v1.1.7 // indirect
    '';
    expected = {
      module = "github.com/airRnot1106/goda-wakachi.vim";
      go = "1.26";
    };
  };

  testCommentAfterModule = {
    expr = (goMod.moduleAndGoLines "module github.com/x/goda-x.vim // the plugin\ngo 1.26\n").module;
    expected = "github.com/x/goda-x.vim";
  };

  testModuleBlockIsNotAPath = {
    expr = (goMod.moduleAndGoLines "module (\n\tgithub.com/x/goda-x.vim\n)\ngo 1.26\n").module;
    expected = null;
  };

  testGoWithPatch = {
    expr = goMod.goVersion "1.26.0";
    expected = {
      major = "1";
      minor = "26";
    };
  };

  testGoWithoutPatch = {
    expr = goMod.goVersion "1.26";
    expected = {
      major = "1";
      minor = "26";
    };
  };

  testNames = {
    expr = {
      inherit (goMod.read ./fixture) modulePath baseName name;
    };
    expected = {
      modulePath = "github.com/airRnot1106/goda-fixture.vim";
      baseName = "goda-fixture.vim";
      name = "goda-fixture";
    };
  };

  testMajorVersionSuffixIsNotTheName = {
    expr = map goMod.baseName [
      "example.com/goda-x.vim/v2"
      "example.com/goda-x.vim/v10"
      "example.com/goda-x.vim/v1"
    ];
    expected = [
      "goda-x.vim"
      "goda-x.vim"
      "v1"
    ];
  };

  testNoGoLine = {
    expr = fails (goMod.read ./cases/no-go-line).go;
    expected = true;
  };
}
