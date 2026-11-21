# goda.nix

Nix flake that exports `lib.buildGodaPlugin`, a helper for building [goda.vim](https://github.com/Shougo/goda.vim) plugins. It uses `buildGoModule` to compile the Go binary and `buildVimPlugin` to bundle it for Vim and Neovim.

> [!WARNING]
> This project is under active development and is not yet stable. The API may change without notice.

## Usage

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
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      plugin = goda-nix.lib.buildGodaPlugin pkgs {
        src = ./.;
        version = "0.1.0";
        vendorHash = "sha256-...";
      };
    in
    {
      packages.aarch64-darwin = {
        default = plugin;
        goda-xx = plugin.binary;
      };
    };
}
```

For a repository whose Go module path ends in `goda-xx.vim`:

- `plugin` is the Vim plugin. It holds `LICENSE`, the Vim runtime directories of the repository (`autoload`, `plugin`, `doc`, `lua`, and so on), and the binary at `bin/goda-xx`. It depends on `plugin.godaVim`, so installing it installs goda.vim too.
- `plugin.binary` is the Go binary alone, at `bin/goda-xx`.
- `plugin.godaVim` is goda.vim as a Vim plugin, at the version in `go.mod`.

## Arguments

| Argument | Meaning |
| --- | --- |
| `src` | The root of the plugin repository, as a path. `go.mod` and the main package are at its root. |
| `version` | The version of the plugin. |
| `vendorHash` | The hash of the Go modules, as for `buildGoModule`. |
| anything else | Passed to `buildGoModule`, for example `preBuild` or `postInstall`. |

The name `goda-xx` comes from the module path in `go.mod`, without the `.vim` suffix. The Go toolchain comes from the `go` line, so `go 1.26` builds with `buildGo126Module`.

`buildGodaPlugin` sets `pname`, `proxyVendor`, `installPhase`, and `meta.mainProgram`. Passing one of them is an error.

Files that `postInstall` adds under `$out` are in the Vim plugin too. A file at `$out/share/goda-xx/data` is at `share/goda-xx/data` in the plugin.

## Checks

Make a check from the binary with `overrideAttrs`:

```nix
checks.aarch64-darwin.e2e = plugin.binary.overrideAttrs (prev: {
  name = "goda-xx-e2e";
  doCheck = true;
  nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.vim pkgs.neovim ];
  checkPhase = ''
    export HOME=$TMPDIR
    go test -v -count=1 ./e2e
  '';
  installPhase = "touch $out";
});
```

A test that needs goda.vim on the runtimepath can ask the go command where it is. This works inside the check and outside Nix, and gives the version in `go.mod`.

```go
out, err := exec.Command("go", "list", "-m", "-f", "{{.Dir}}", "github.com/Shougo/goda.vim").Output()
```

## Updating vendorHash

After `go.mod` or `go.sum` changes, run [nix-update](https://github.com/Mic92/nix-update) with the name of the package that holds `plugin.binary`:

```sh
nix run nixpkgs#nix-update -- --flake goda-xx --version=skip
```
