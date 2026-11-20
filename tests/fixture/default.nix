# The arguments the fixture plugin passes to mkFlake, as a plugin's flake.nix
# writes them. Each setting is used once.
#
# `nix-update --flake fixture --version=skip` rewrites vendorHash here.
{ nixpkgs }:
{
  inherit nixpkgs;
  src = ./.;
  version = "0.0.0";
  vendorHash = "sha256-vCGTOsjo38KFNjtvhKrc8pt9Q3pRi8+yqwNoJSMF0J8=";
  perSystem =
    { pkgs, ... }:
    let
      greeting = pkgs.writeText "greeting" "hello\n";
    in
    {
      binary.postInstall = ''
        install -Dm444 ${greeting} $out/share/goda-fixture/greeting
      '';
      check = {
        env.GODA_FIXTURE_GREETING = greeting;
        nativeBuildInputs = [ pkgs.jq ];
      };
      outputs = plugin: {
        checks = {
          go-check = plugin.goCheck {
            name = "go-check";
            nativeBuildInputs = [ pkgs.hello ];
            script = ''
              fail() { echo "$1" >&2; exit 1; }
              [ "$GODA_FIXTURE_E2E_STRICT" = 1 ] || fail "the e2e contract did not reach a goCheck"
              [ -f "$GODA_FIXTURE_E2E_GODA/autoload/goda.vim" ] || fail "GODA_FIXTURE_E2E_GODA is not goda.vim"
              [ "$(cat "$GODA_FIXTURE_GREETING")" = hello ] || fail "check.env did not reach a goCheck"
              command -v jq > /dev/null || fail "check.nativeBuildInputs did not reach a goCheck"
              command -v hello > /dev/null || fail "nativeBuildInputs did not reach a goCheck"
              [ -w "$HOME" ] || fail "HOME is not writable in a goCheck"
              go version | grep -qF " go1.26" || fail "a goCheck does not run the Go of go.mod"
              go mod download -json github.com/Shougo/goda.vim > /dev/null || fail "the Go modules are not on the file proxy"
            '';
          };

          # The plugin as a user installs it: the shipped binary, started by
          # the shipped Vim script, through the shipped goda.vim.
          runtimepath =
            pkgs.runCommand "goda-fixture-runtimepath"
              {
                nativeBuildInputs = [
                  pkgs.vim
                  pkgs.neovim
                ];
              }
              ''
                export HOME=$TMPDIR
                cat > driver.vim <<'EOF'
                set runtimepath^=${plugin.runtimepath}
                try
                  call writefile([goda_fixture#reverse('goda')], $ANSWER)
                catch
                  call writefile([v:exception], $ANSWER)
                endtry
                qall!
                EOF
                for editor in "vim -u NONE -N -n -i NONE -es -S" "nvim -u NONE -n -i NONE --headless -S"; do
                  export ANSWER=$PWD/answer-''${editor%% *}
                  # Without a terminal, an editor that fails to quit waits for
                  # input and the build never ends.
                  timeout 60 $editor driver.vim < /dev/null || true
                  if [ "$(cat "$ANSWER")" != adog ]; then
                    echo "''${editor%% *}: the shipped plugin answered: $(cat "$ANSWER")" >&2
                    exit 1
                  fi
                done
                touch $out
              '';
        };
      };
    };
}
