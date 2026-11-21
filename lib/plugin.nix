{ lib, goMod }:
{
  build =
    {
      pkgs,
      mod,
      pinned,
      vimModules,
      binary,
      check,
    }:
    let
      toolchain = "buildGo${mod.go.major}${mod.go.minor}Module";
      buildGoModule =
        pkgs.${toolchain}
          or (throw "goda.nix: go.mod says go ${mod.go.major}.${mod.go.minor}, and this nixpkgs has no ${toolchain}. Raise the go line in go.mod to a Go that this nixpkgs has.");

      owned =
        setting: names: attrs:
        let
          clash = lib.intersectLists names (builtins.attrNames attrs);
        in
        if clash == [ ] then
          attrs
        else
          throw "goda.nix: ${setting} sets ${toString clash}, which goda.nix owns.";

      # The module trees below are read from goModules. It is a GOPROXY cache
      # only with proxyVendor, and only the goModules fixed by this vendorHash
      # is the download the binary is built from.
      pin = [
        "pname"
        "version"
        "src"
        "vendorHash"
        "proxyVendor"
        "goModules"
      ];

      binaryAttrs = owned "binary" (pin ++ [ "installPhase" ]) binary;
      binaryMeta = owned "binary.meta" [ "mainProgram" ] (binary.meta or { });
      binaryEnv = owned "binary.env" (builtins.attrNames contract) (binary.env or { });

      checkAttrs = owned "check" (
        pin
        ++ [
          "doCheck"
          "checkPhase"
          "installPhase"
        ]
      ) check;
      checkEnv = owned "check.env" (builtins.attrNames contract) (check.env or { });

      goBinary = buildGoModule (
        # nix-update takes the file to edit from the position of src, and
        # rejects a version whose position is outside the flake. `//` keeps the
        # positions the caller's flake.nix gave them. `inherit` would move them
        # here.
        pinned
        // {
          subPackages = [ "." ];
          doCheck = false;
        }
        // binaryAttrs
        // {
          pname = mod.name;
          proxyVendor = true;
          env = binaryEnv;
          installPhase = ''
            runHook preInstall
            install -Dm755 "$GOPATH/bin/${mod.baseName}" "$out/bin/${mod.name}"
            runHook postInstall
          '';
          meta = binaryMeta // {
            mainProgram = mod.name;
          };
        }
      );

      goModFiles = lib.fileset.toSource {
        root = pinned.src;
        fileset = lib.fileset.unions [
          (pinned.src + "/go.mod")
          (pinned.src + "/go.sum")
        ];
      };

      moduleTree =
        modulePath:
        pkgs.runCommand "${goMod.baseName modulePath}-source" { nativeBuildInputs = [ goBinary.go ]; } ''
          export GOPROXY=file://${goBinary.goModules} GOSUMDB=off GOTOOLCHAIN=local
          export GOPATH=$TMPDIR/go GOMODCACHE=$TMPDIR/mod GOCACHE=$TMPDIR/cache HOME=$TMPDIR
          # The go command ignores a go.mod in the system temp root, which the
          # build directory is.
          mkdir module && cd module
          cp ${goModFiles}/go.mod ${goModFiles}/go.sum .
          chmod u+w go.mod go.sum
          go mod download ${modulePath}
          cp -r "$(go list -m -f '{{.Dir}}' ${modulePath})" $out
          chmod -R u+w $out
        '';

      versionIsInGoMod = "gomod";

      modules = lib.genAttrs ([ goMod.godaVim ] ++ vimModules) (
        modulePath:
        pkgs.vimUtils.buildVimPlugin {
          pname = goMod.baseName modulePath;
          version = versionIsInGoMod;
          src = moduleTree modulePath;
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

      vimPlugin = pkgs.vimUtils.buildVimPlugin {
        pname = mod.baseName;
        inherit (pinned) version;
        src = lib.fileset.toSource {
          root = pinned.src;
          fileset = lib.fileset.unions (
            map (name: lib.fileset.maybeMissing (pinned.src + "/${name}")) runtimeNames
          );
        };
        dependencies = builtins.attrValues modules;
        preInstall = ''
          cp -r ${goBinary}/. .
        '';
      };

      envPrefix = "${goMod.envStem mod.name}_E2E";
      contract =
        lib.mapAttrs' (
          modulePath: plugin: lib.nameValuePair "${envPrefix}_${goMod.envStem modulePath}" "${plugin}"
        ) modules
        // {
          "${envPrefix}_STRICT" = "1";
        };

      /**
        goCheck :: { name, script, nativeBuildInputs ? [ ] } -> derivation

        Runs script after the binary's build phase, so the caller's binary
        attributes apply and the Go modules are on the file proxy. HOME is the
        build directory. The environment is the binary's, then check.env, then
        the e2e contract. Succeeds when script does.
      */
      goCheck =
        {
          name,
          script,
          nativeBuildInputs ? [ ],
        }:
        goBinary.overrideAttrs (
          prev:
          removeAttrs checkAttrs [
            "env"
            "nativeBuildInputs"
          ]
          // {
            pname = "${mod.name}-${name}";
            # buildGoModule names goModules after pname, so without this each
            # check would fetch the modules again under its own name.
            inherit (goBinary) goModules;
            doCheck = true;
            nativeBuildInputs =
              prev.nativeBuildInputs ++ checkAttrs.nativeBuildInputs or [ ] ++ nativeBuildInputs;
            env = prev.env // checkEnv // contract;
            checkPhase = ''
              runHook preCheck
              export HOME=$TMPDIR
              ${script}
              runHook postCheck
            '';
            installPhase = "touch $out";
          }
        );

      devShell = pkgs.mkShell {
        packages = [
          goBinary.go
          pkgs.vim
          pkgs.neovim
        ];
      };
    in
    {
      plugin = {
        inherit (mod) name;
        inherit (goBinary) go;
        binary = goBinary;
        inherit vimPlugin goCheck devShell;
        runtimepath = lib.concatMapStringsSep "," toString ([ vimPlugin ] ++ builtins.attrValues modules);
      };

      outputs = {
        packages = {
          ${mod.name} = goBinary;
          vim-plugin = vimPlugin;
          default = vimPlugin;
          goda-vim = modules.${goMod.godaVim};
        };
        checks = {
          unit = goCheck {
            name = "unit";
            script = ''
              packages=$(go list ./... | grep -vx '${mod.modulePath}/e2e')
              go test $packages
            '';
          };
          e2e = goCheck {
            name = "e2e";
            nativeBuildInputs = [
              pkgs.vim
              pkgs.neovim
            ];
            script = "go test -v -count=1 ./e2e";
          };
          vim-plugin = vimPlugin;
        };
        devShells.default = devShell;
      };
    };
}
