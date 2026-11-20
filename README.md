# goda.nix

A Nix flake with one function, `lib.mkFlake`. It builds the flake outputs of a Vim or Neovim plugin that runs on [goda.vim](https://github.com/Shougo/goda.vim): the Go binary, the Vim plugin with the binary in `bin/`, goda.vim itself, the unit and e2e checks, and a dev shell.

goda.nix takes goda.vim from your `go.mod` and from nowhere else. Your flake has no `goda-vim` input. The Go library that the binary links and the Vim files on the runtimepath come from one Go module download, so they are the same version. `go.mod` stays the one pin, for Nix and for people who run `go build` and install the plugin with a plugin manager.

## Minimal call

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    goda-nix = {
      url = "github:airRnot1106/goda.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, goda-nix, ... }:
    goda-nix.lib.mkFlake {
      inherit nixpkgs;
      src = ./.;
      version = "0.1.0";
      vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
}
```

The `vendorHash` above is a placeholder. [Update vendorHash](#update-vendorhash) replaces it with the real hash.

For a plugin whose module path ends in `goda-xx.vim`, the call returns these outputs for each supported system.

| Output | Contents |
| --- | --- |
| `packages.<system>.goda-xx` | The Go binary, at `bin/goda-xx`. nix-update targets this package. |
| `packages.<system>.vim-plugin`, `packages.<system>.default` | The Vim plugin: the runtime files, `bin/goda-xx`, and anything else the binary installs. It depends on `goda-vim` and on each module in `vimModules`. |
| `packages.<system>.goda-vim` | goda.vim as a Vim plugin, at the version that `go.mod` resolves to. |
| `checks.<system>.unit` | `go test` on every package except `./e2e`. |
| `checks.<system>.e2e` | `go test -v -count=1 ./e2e`, with `vim` and `nvim` on `PATH`. |
| `checks.<system>.vim-plugin` | Builds the Vim plugin, so `nix flake check` covers the package you ship. |
| `devShells.<system>.default` | The Go toolchain of `go.mod`, Vim, and Neovim. |

## Conventions your repository must follow

goda.nix reads these facts from the repository. No argument overrides them.

- **The name comes from the module path.** `module github.com/you/goda-xx.vim` in `go.mod` gives the name `goda-xx`. The name is the last element of the module path without `.vim`. A major version suffix such as `/v2` is skipped, as the go command skips it. The binary is `bin/goda-xx`, the package is `packages.<system>.goda-xx`, and the check variables start with `GODA_XX_E2E_`.
- **The Go toolchain comes from the `go` line.** `go 1.26` and `go 1.26.0` both select `buildGo126Module`. If your nixpkgs has no toolchain for that version, evaluation fails with a message that says to raise the `go` line. goda.nix does not fall back to another Go.
- **`go.mod` is at the root of `src`, and the root package is the binary.** `go.mod` requires `github.com/Shougo/goda.vim`.
- **The Vim script starts `bin/<name>` under the plugin root.**
- **The editor tests are the package `./e2e`.** The `e2e` check runs that package, and the `unit` check runs every other package.
- **The Vim plugin is `LICENSE` plus every Vim runtime directory that exists at the root.** The directories are `after`, `autoload`, `colors`, `compiler`, `doc`, `ftdetect`, `ftplugin`, `import`, `indent`, `keymap`, `lang`, `lua`, `plugin`, `queries`, `rplugin`, and `syntax`. Go sources, tests, and `flake.nix` stay out.

### Variables that every check sets

| Variable | Value |
| --- | --- |
| `GODA_XX_E2E_GODA` | The goda.vim plugin, the same store path as `packages.<system>.goda-vim`. |
| `GODA_XX_E2E_<MODULE>` | One variable for each module in `vimModules`. `github.com/you/goda-ks.vim` gives `GODA_XX_E2E_GODA_KS`. |
| `GODA_XX_E2E_STRICT` | `1`. Your tests fail instead of skipping when an editor is missing. |

Your e2e test puts the directory in `GODA_XX_E2E_GODA` on the runtimepath. Outside Nix the variable is unset. There, `go list -m -f '{{.Dir}}' github.com/Shougo/goda.vim` prints the directory of the same goda.vim in the Go module cache.

No setting can change these variables. A setting that names one of them fails evaluation.

## Arguments

| Argument | Meaning |
| --- | --- |
| `nixpkgs` | Your nixpkgs input. goda.nix builds everything from `nixpkgs.legacyPackages.<system>`. |
| `src` | The root of the plugin repository, as a path such as `./.`. goda.nix reads `go.mod` from it during evaluation. |
| `version` | The version of the plugin. |
| `vendorHash` | The hash of the Go module download. Write it as a literal string in `flake.nix`, because nix-update replaces that string. |
| `vimModules` | Optional. A list of Go module paths, other than goda.vim, whose Vim files your plugin needs at runtime. Each module must be a dependency in `go.mod`. |
| `perSystem` | Optional. A function from `{ pkgs, system }` to the settings below. |

goda.nix resolves goda.vim and each module in `vimModules` with the go command, against the module download that the binary is built from. A `replace` directive that points at another module version applies to the Vim files as it applies to the Go code. A module in `vimModules` that `go.mod` does not depend on fails the build with `not a known dependency`.

## Settings

`perSystem` returns an attribute set with any of three keys. An unknown key fails evaluation.

```nix
perSystem =
  { pkgs, system }:
  {
    binary = { };
    check = { };
    outputs = plugin: { };
  };
```

### `binary`

Extra attributes for `buildGoModule`, such as `preBuild` or `postInstall`. Every check is built from the binary, so these attributes reach every check too.

- goda.nix owns `pname`, `version`, `src`, `vendorHash`, `proxyVendor`, `goModules`, `installPhase`, and `meta.mainProgram`. Setting one of them fails evaluation.
- `postInstall` runs after the binary is at `$out/bin/<name>`.
- The Vim plugin holds everything the binary installs under `$out`. A file at `$out/share/goda-xx/data` is at `share/goda-xx/data` in the plugin.
- `preBuild` also runs in the derivation that downloads the Go modules, as it does in every `buildGoModule` package.

### `check`

Extra attributes for every check, and only for checks. The binary does not get them.

- `check.env` adds environment variables. `check.env.MY_DICT = pkgs.fetchurl { ... };` gives every test the file.
- `check.nativeBuildInputs` adds tools to `PATH`.
- Any other attribute replaces the binary's attribute of that name. `check.__darwinAllowLocalNetworking = true;` lets tests bind localhost in the macOS sandbox.
- goda.nix owns `pname`, `version`, `src`, `vendorHash`, `proxyVendor`, `goModules`, `doCheck`, `checkPhase`, and `installPhase`. Setting one of them fails evaluation.

### `outputs`

A function from the `plugin` record to extra per-system flake outputs. goda.nix merges the result over the default outputs, one level deep.

- `checks.lint = ...;` joins `checks.unit` and `checks.e2e`.
- `checks.unit = ...;` replaces the default `unit` check.
- An output that goda.nix does not define, such as `apps` or `formatter`, is added as given.

`binary` and `check` cannot use the `plugin` record. Only `outputs` can.

## The `plugin` record

| Attribute | Value |
| --- | --- |
| `name` | The plugin name, `goda-xx`. |
| `go` | The Go toolchain chosen from `go.mod`. |
| `binary` | The Go binary, `packages.<system>.goda-xx`. |
| `vimPlugin` | The Vim plugin, `packages.<system>.vim-plugin`. |
| `runtimepath` | The store paths of the Vim plugin, goda.vim, and each module in `vimModules`, joined with commas for `set runtimepath^=`. |
| `goCheck` | A function that makes a check. |
| `devShell` | The default dev shell, for `inputsFrom`. |

`plugin.goCheck { name, script, nativeBuildInputs ? [ ] }` returns a check that runs `script` after the build phase of the binary. The Go modules are available offline, `HOME` is writable, and the environment holds `check.env` and the variables that every check sets. goda.nix makes `checks.unit` and `checks.e2e` with the same function.

```nix
outputs = plugin: {
  checks.lint-go = plugin.goCheck {
    name = "lint-go";
    nativeBuildInputs = [ pkgs.golangci-lint ];
    script = "golangci-lint run ./...";
  };
  devShells.default = pkgs.mkShell {
    inputsFrom = [ plugin.devShell ];
    packages = [ pkgs.golangci-lint ];
  };
};
```

For an output that is not per system, merge it at the top level: `goda-nix.lib.mkFlake { ... } // { overlays.default = ...; }`.

## Supported systems

`mkFlake` returns outputs for `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.

`x86_64-darwin` is absent because nixpkgs 26.11 dropped support for it. Evaluating a package for that system throws.

No attribute name in the result depends on `pkgs`, so `nix flake show` lists the outputs of a system without evaluating its packages.

## Update vendorHash

`vendorHash` changes when `go.mod` or `go.sum` changes. Run nix-update in the plugin repository:

```sh
nix run nixpkgs#nix-update -- --flake goda-xx --version=skip
```

nix-update downloads the modules and rewrites the `vendorHash` string in your `flake.nix`. It finds the file from the place where `flake.nix` writes `src` and `version`. Write both in the `mkFlake` call, or bind them with `inherit` in that file.

If nix-update reports that a file `is not in` your flake, name the file:

```sh
nix run nixpkgs#nix-update -- --flake goda-xx --version=skip --override-filename flake.nix
```

goda.nix builds with `proxyVendor = true`, so the hash differs from the hash of a `buildGoModule` package that vendors its modules. A plugin that moves to goda.nix runs the command once.

## Test goda.nix itself

`nix flake check` in this repository builds the fixture plugin in `tests/fixture` with `mkFlake` and runs its checks. The fixture's e2e test sends a request from Vim and from Neovim through goda.vim to the Go binary and reads the answer.

To test a goda.nix branch against your plugin before you update the input, run this command in the plugin repository:

```sh
nix flake check --override-input goda-nix github:airRnot1106/goda.nix/<branch>
```
