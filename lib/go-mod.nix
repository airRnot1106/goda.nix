# What goda.nix reads from go.mod at evaluation time, and the names it derives
# from module paths.
#
# Module versions are not read here. The go command resolves them when
# plugin.nix extracts a module, so require, replace, and minimal version
# selection have one implementation, Go's.
{ lib }:
rec {
  godaVim = "github.com/Shougo/goda.vim";

  /**
    read :: path -> Mod

    Mod = {
      modulePath  # "github.com/airRnot1106/goda-ks.vim"
      baseName    # "goda-ks.vim". go install names the program after it.
      name        # "goda-ks". The installed program, the package attribute, the env stem.
      go          # { major = "1"; minor = "26"; } from "go 1.26" or "go 1.26.0"
    }

    Throws, naming go.mod, when the module or go line is missing.
  */
  read =
    src:
    let
      file = src + "/go.mod";
      parsed = parse (builtins.readFile file);
      need =
        what: value:
        if value == null then throw "goda.nix: ${toString file} has no ${what} line" else value;
      modulePath = need "module" parsed.module;
    in
    {
      inherit modulePath;
      baseName = baseName modulePath;
      name = lib.removeSuffix ".vim" (baseName modulePath);
      go = goVersion (need "go" parsed.go);
    };

  /**
    parse :: string -> { module :: string or null; go :: string or null; }

    Both are single-line directives, so each line is matched alone after its
    // comment is stripped. Every other line is ignored, including require and
    replace blocks.
  */
  parse =
    text:
    let
      lines = map (line: lib.trim (builtins.head (lib.splitString "//" line))) (
        lib.splitString "\n" text
      );
      first =
        regex:
        let
          found = lib.findFirst (match: match != null) null (map (builtins.match regex) lines);
        in
        if found == null then null else builtins.head found;
    in
    {
      module = first ''module[[:space:]]+"?([^"[:space:]]+)"?'';
      go = first "go[[:space:]]+([0-9][^[:space:]]*)";
    };

  /**
    baseName :: string -> string
      "github.com/airRnot1106/goda-ks.vim"    -> "goda-ks.vim"
      "github.com/airRnot1106/goda-ks.vim/v2" -> "goda-ks.vim"
    The go command names a program after the last path element, and after the
    one before it when the last is a major version suffix.
  */
  baseName =
    modulePath:
    let
      elements = lib.splitString "/" modulePath;
      last = lib.last elements;
    in
    if builtins.match "v([2-9]|[1-9][0-9]+)" last != null && builtins.length elements > 1 then
      lib.last (lib.init elements)
    else
      last;

  /**
    goVersion :: string -> { major :: string; minor :: string; }
      "1.26"   -> { major = "1"; minor = "26"; }
      "1.26.0" -> { major = "1"; minor = "26"; }
    The patch level is dropped because nixpkgs names toolchains by minor version.
  */
  goVersion =
    version:
    let
      parts = builtins.match "([0-9]+)\\.([0-9]+)(\\.[0-9]+)?" version;
    in
    if parts == null then
      throw "goda.nix: cannot read the go version ${version} in go.mod"
    else
      {
        major = builtins.elemAt parts 0;
        minor = builtins.elemAt parts 1;
      };

  /**
    envStem :: string -> string
    The stem of an environment variable for a plugin name or a module path.
      "goda-ks"                             -> "GODA_KS"
      "github.com/Shougo/goda.vim"          -> "GODA"
      "github.com/airRnot1106/goda-ks.vim"  -> "GODA_KS"
  */
  envStem =
    nameOrPath:
    lib.toUpper (
      builtins.replaceStrings [ "-" "." ] [ "_" "_" ] (lib.removeSuffix ".vim" (baseName nameOrPath))
    );
}
