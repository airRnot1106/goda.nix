{
  /**
    The Vim plugin of a goda.vim plugin repository, with its Go binary inside.

    buildGodaPlugin pkgs {
      src         # a path (./.) with go.mod and the main package at its root.
      version     # the plugin's version label.
      vendorHash  # SRI hash of the proxyVendor module download, a literal in the caller's file.
      ...         # any other buildGoModule attribute, such as preBuild or postInstall.
    }

    Returns the Vim plugin: every Vim runtime directory at the root of src,
    LICENSE, and whatever the binary installs, so the binary is at
    bin/<name>. Its `binary` attribute is the Go binary.

    The plugin name and the Go toolchain come from go.mod. pname, proxyVendor,
    installPhase, and meta.mainProgram are set here, and passing one throws.

    goda.vim is not part of the result. The binary is built with proxyVendor,
    so its module download holds whole modules, and a test that runs in a
    check made from the binary finds goda.vim's Vim files with
    `go list -m -f '{{.Dir}}' github.com/Shougo/goda.vim`.
  */
  buildGodaPlugin =
    pkgs:
    {
      src,
      version,
      vendorHash,
      ...
    }@args:
    let
      inherit (pkgs) lib;
      goMod = import ./go-mod.nix { inherit lib; };

      mod =
        if builtins.isPath src then
          goMod.read src
        else
          throw "goda.nix: src must be a path such as ./. , got a ${builtins.typeOf src}";

      toolchain = "buildGo${mod.go.major}${mod.go.minor}Module";
      buildGoModule =
        pkgs.${toolchain}
          or (throw "goda.nix: go.mod says go ${mod.go.major}.${mod.go.minor}, and this nixpkgs has no ${toolchain}. Raise the go line in go.mod to a Go that this nixpkgs has.");

      goInstallsAs = mod.baseName;

      owned =
        what: names: attrs:
        let
          clash = lib.intersectLists names (builtins.attrNames attrs);
        in
        if clash == [ ] then
          attrs
        else
          throw "goda.nix: ${what} sets ${toString clash}, which goda.nix owns.";

      binary = buildGoModule (
        {
          subPackages = [ "." ];
          doCheck = false;
        }
        # nix-update edits the file where src and version were written.
        # Passing args through keeps that the caller's file.
        # `inherit src version vendorHash` would make it this file.
        // owned "buildGodaPlugin" [ "pname" "proxyVendor" "installPhase" ] args
        // {
          pname = mod.name;
          proxyVendor = true;
          installPhase = ''
            runHook preInstall
            install -Dm755 "$GOPATH/bin/${goInstallsAs}" "$out/bin/${mod.name}"
            runHook postInstall
          '';
          meta = owned "meta" [ "mainProgram" ] (args.meta or { }) // {
            mainProgram = mod.name;
          };
        }
      );

      runtimeNames = [
        "LICENSE"
        "after"
        "autoload"
        "colors"
        "compiler"
        "doc"
        "ftdetect"
        "ftplugin"
        "import"
        "indent"
        "keymap"
        "lang"
        "lua"
        "plugin"
        "queries"
        "rplugin"
        "syntax"
      ];
    in
    pkgs.vimUtils.buildVimPlugin {
      pname = mod.baseName;
      inherit version;
      src = lib.fileset.toSource {
        root = src;
        fileset = lib.fileset.unions (map (name: lib.fileset.maybeMissing (src + "/${name}")) runtimeNames);
      };
      preInstall = ''
        cp -r ${binary}/. .
      '';
      passthru = { inherit binary; };
    };
}
