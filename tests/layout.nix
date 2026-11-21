{ pkgs, packages }:
let
  plugin = packages.vim-plugin;
  goda = packages.goda-vim;
in
pkgs.runCommand "goda-nix-layout" { } ''
  fail() { echo "$1" >&2; exit 1; }
  [ -x ${packages.goda-fixture}/bin/goda-fixture ] || fail "the binary is not installed as bin/goda-fixture"
  [ ! -e ${packages.goda-fixture}/bin/goda-fixture.vim ] || fail "the binary kept the name go install gave it"
  [ -x ${plugin}/bin/goda-fixture ] || fail "bin/goda-fixture is not executable in the Vim plugin"
  [ -f ${plugin}/share/goda-fixture/greeting ] || fail "what binary.postInstall installed is not in the Vim plugin"
  [ -f ${plugin}/autoload/goda_fixture.vim ] || fail "autoload/ is not in the Vim plugin"
  [ -f ${plugin}/plugin/goda_fixture.vim ] || fail "plugin/ is not in the Vim plugin"
  [ -f ${plugin}/doc/tags ] || fail "helptags did not run on doc/"
  for leak in go.mod go.sum main.go internal e2e default.nix; do
    [ ! -e ${plugin}/$leak ] || fail "$leak leaked into the Vim plugin"
  done
  [ -f ${goda}/autoload/goda.vim ] || fail "goda.vim has no autoload/goda.vim"
  grep -qx 'module github.com/Shougo/goda.vim' ${goda}/go.mod || fail "packages.goda-vim is not goda.vim's module tree"
  touch $out
''
