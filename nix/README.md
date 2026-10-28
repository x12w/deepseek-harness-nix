# DeepSeek Harness on NixOS

English | [中文](README.zh.md)

Build the Linux x86_64 desktop application from this fork with Nix flakes. The application uses the upstream Electron desktop shell; Linux desktop support is maintained here.

## Usage

From this checkout:

```sh
nix build
nix run
```

The output provides `bin/deepseek-harness`, `bin/dsh`, a desktop menu entry, and a `dsh://` protocol handler. The CLI supports `dsh --help` and `dsh --version`.

A NixOS or Home Manager flake can install the package through this input:

```nix
inputs.deepseek-harness = {
  url = "github:x12w/deepseek-harness-nix/codex/nix-packaging";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Use `inputs.deepseek-harness.packages.x86_64-linux.default` in `environment.systemPackages` or `home.packages`. Only x86_64 Linux is supported.

Configure credentials inside the application. Harness data defaults to `~/.dsh`, or `DSH_HOME` when set. The desktop profile lives under `profiles/desktop` within that directory. Nix does not store credentials or replace mutable user settings. Application updates are managed by the flake lock.

## Maintenance

[`default.nix`](default.nix) builds the source tree and its pinned pnpm dependencies. Electron stays at the exact version required by `node-addon-require-builtin`; the CLI uses Electron in Node mode for the same reason. The package builds a static Landlock launcher and sets the Bash executable to its Nix store path.

[`primary-runtime.nix`](primary-runtime.nix) reads the upstream [runtime lock](../scripts/primary-runtime/lock.json) and prepares the Python document-processing environment. Node.js and pnpm come from Nix. The application copies this runtime into its writable data directory.

After merging upstream changes, check the pnpm and Electron versions against the package manifests. If dependencies changed, set `pnpmDeps.hash` to an empty string, build once, and replace it with the hash reported by Nix. Run `nix flake check` and launch the desktop before updating consumers. The build checks the CLI version, Node internal access, PTY execution, and Python imports. Graphical startup requires a separate smoke check.
