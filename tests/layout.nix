{ pkgs, plugin }:
pkgs.runCommand "goda-nix-layout" { } ''
  fail() { echo "$1" >&2; exit 1; }
  [ -x ${plugin.binary}/bin/goda-fixture ] || fail "the binary is not installed as bin/goda-fixture"
  [ ! -e ${plugin.binary}/bin/goda-fixture.vim ] || fail "the binary kept the name go install gave it"
  [ -x ${plugin}/bin/goda-fixture ] || fail "bin/goda-fixture is not executable in the Vim plugin"
  [ -f ${plugin}/share/goda-fixture/greeting ] || fail "what postInstall installed is not in the Vim plugin"
  [ -f ${plugin}/autoload/goda_fixture.vim ] || fail "autoload/ is not in the Vim plugin"
  [ -f ${plugin}/plugin/goda_fixture.vim ] || fail "plugin/ is not in the Vim plugin"
  [ -f ${plugin}/doc/tags ] || fail "helptags did not run on doc/"
  for leak in go.mod go.sum main.go internal e2e default.nix; do
    [ ! -e ${plugin}/$leak ] || fail "$leak leaked into the Vim plugin"
  done
  [ -f ${plugin.godaVim}/autoload/goda.vim ] || fail "godaVim has no autoload/goda.vim"
  touch $out
''
