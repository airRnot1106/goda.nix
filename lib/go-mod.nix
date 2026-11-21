{ lib }:
rec {
  read =
    src:
    let
      file = src + "/go.mod";
      parsed = moduleAndGoLines (builtins.readFile file);
      need =
        what: value:
        if value == null then
          throw "goda.nix: ${toString file} has no single-line ${what} directive"
        else
          value;
      modulePath = need "module" parsed.module;
    in
    {
      inherit modulePath;
      baseName = baseName modulePath;
      name = lib.removeSuffix ".vim" (baseName modulePath);
      go = goVersion (need "go" parsed.go);
    };

  moduleAndGoLines =
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
      module = first ''module[[:space:]]+"?([^"([:space:]]+)"?'';
      go = first "go[[:space:]]+([0-9][^[:space:]]*)";
    };

  # The go command names a program after the last path element, and after the
  # one before it when the last is a major version suffix.
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
}
