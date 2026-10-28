{
  lib,
  stdenv,
  fetchurl,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  nodejs,
  python3,
  writableTmpDirAsHomeHook,
  callPackage,
  electron_44-bin,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  autoPatchelfHook,
  bash,
  xdg-utils,
  xdg-user-dirs,
  ripgrep,
  git,
  pkgsStatic,
  libx11,
  libxi,
  libxcb,
  libxkbcommon,
  ncurses,
  sourceRevision ? "0000000000000000000000000000000000000000",
}:
let
  pnpm = pnpm_11.override {
    version = "11.28.5";
    hash = "sha256-HvTkR6aHE2VgZPPxdMD0RxmWCgQ6P+IpkWnQjPHb+O4=";
  };
  # node-addon-require-builtin validates the exact Node/V8 fingerprint.
  electron = electron_44-bin.overrideAttrs {
    version = "44.7.0";
    src = fetchurl {
      url = "https://github.com/electron/electron/releases/download/v44.7.0/electron-v44.7.0-linux-x64.zip";
      sha256 = "3ae7d5bdad61c664486c6ab61361dd084d064c8c08af8d13a687096e18ce555a";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "deepseek-harness";
  version = (lib.importJSON ../package.json).version;

  src = lib.cleanSourceWith {
    src = lib.cleanSource ../.;
    filter =
      path: type:
      !(builtins.elem (lib.removePrefix "${toString ../.}/" (toString path)) [
        "nix"
        "flake.nix"
        "flake.lock"
      ]);
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname src;
    inherit pnpm;
    fetcherVersion = 5;
    hash = "sha256-Z4jIL3Rfuzj7VBtAi+tbxLR5hOgYjFl+AQkZ+KiGvgY=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    python3
    writableTmpDirAsHomeHook
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libx11
    libxi
    libxcb
    libxkbcommon
    ncurses
  ];

  # Preserve bundled executables with embedded resources; autoPatchelf owns ELF edits.
  dontStrip = true;
  dontPatchELF = true;

  # Use the upstream unpackaged application path, with Nix owning updates.
  postPatch = ''
    substituteInPlace apps/desktop/scripts/desktop-build-paths.mjs \
      --replace-fail "new Set(['mac-arm64', 'mac-x64', 'win-x64'])" \
        "new Set(['mac-arm64', 'mac-x64', 'win-x64', 'linux-x64'])" \
      --replace-fail "'win-x64': { platform: 'win32', arch: 'x64' }," \
        "'win-x64': { platform: 'win32', arch: 'x64' }, 'linux-x64': { platform: 'linux', arch: 'x64' },"
    substituteInPlace packages/terminal/terminal-bash/src/config.ts \
      --replace-fail "'/bin/bash'" "'${bash}/bin/bash'"
  '';

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    npm_config_nodedir = "${nodejs}";
    LEFTHOOK = "0";
    DSH_CLIENT_COMMIT_HASH = sourceRevision;
    DSH_GATE_CONCURRENCY = "4";
    pnpm_config_enable_global_virtual_store = "false";
  };

  buildPhase = ''
    runHook preBuild
    pnpm rebuild esbuild node-pty koffi
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app="$out/lib/deepseek-harness"
    mkdir -p "$app" "$out/bin"
    cp -a apps packages vendor native benchmarks website python node_modules \
      package.json pnpm-workspace.yaml LICENSE THIRD_PARTY_NOTICES.md "$app/"
    # Test fixtures reference repository-only snapshots outside the runtime tree.
    for workspace in apps packages vendor native benchmarks website python; do
      find "$app/$workspace" -type d -name node_modules -prune -o \
        -type d -name tests -prune -exec rm -rf {} +
    done
    # These bundled Android/musl variants cannot run in this glibc package.
    find "$app/node_modules" -type f \
      \( -path '*/prebuilds/android-*/*' -o -path '*/musl_x64/koffi.node' \
         -o -name 'index.linux-x64-musl.node' \) -delete
    find "$app" -path '*/node_modules/.bin/*' -type f \
      -exec sed -i "s|$PWD|$app|g" {} +
    install -Dm755 ${finalAttrs.passthru.landlock}/bin/landlock-run \
      "$app/native/system/packages/linux-x64/bin/landlock-run"
    cp ${./prepare-desktop.ts} "$app/apps/desktop/scripts/nix-prepare.ts"
    cd "$app"
    export DSH_NIX_ELECTRON=${electron}/bin/electron
    node --import tsx/esm apps/desktop/scripts/nix-prepare.ts

    mkdir -p "$app/runtime"
    ln -s ${finalAttrs.passthru.primaryRuntime} "$app/runtime/primary-runtime"
    cp -a packages/skill/skill-office/assets "$app/runtime/office-skills"
    patchShebangs apps/desktop/scripts/node-bin

    makeWrapper ${electron}/bin/electron "$out/bin/deepseek-harness" \
      --add-flags "$app/apps/desktop --class=deepseek-harness" \
      --set DSH_DESKTOP_DSH_DIR "$app/desktop-runtime" \
      --set DSH_DESKTOP_PRIMARY_RUNTIME_DIR "$app/runtime/primary-runtime" \
      --set DSH_DESKTOP_PNPM_ENTRY "${pnpm}/libexec/pnpm/bin/pnpm.mjs" \
      --set DSH_DESKTOP_OPEN_DEVTOOLS 0 \
      --unset ELECTRON_RUN_AS_NODE \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          nodejs
          pnpm
          xdg-utils
          xdg-user-dirs
          ripgrep
          git
        ]
      }

    makeWrapper ${electron}/bin/electron "$out/bin/dsh" \
      --set ELECTRON_RUN_AS_NODE 1 \
      --add-flags "--expose-internals $app/apps/cli/lib/bin.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          nodejs
          pnpm
          xdg-utils
          xdg-user-dirs
          ripgrep
          git
        ]
      }

    install -Dm644 apps/desktop/resources/icon-windows.png \
      "$out/share/icons/hicolor/1024x1024/apps/deepseek-harness.png"
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "deepseek-harness";
      desktopName = "DeepSeek Harness";
      comment = "DeepSeek AI agent desktop";
      exec = "deepseek-harness %U";
      icon = "deepseek-harness";
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/dsh" ];
      startupWMClass = "deepseek-harness";
    })
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/dsh" --version
    test -s "$out/lib/deepseek-harness/apps/web/dist/index.html"
    ELECTRON_RUN_AS_NODE=1 ${electron}/bin/electron --expose-internals \
      ${./check-runtime.cjs} "$out/lib/deepseek-harness/desktop-runtime" ${bash}/bin/bash
    runHook postInstallCheck
  '';

  passthru.landlock = pkgsStatic.stdenv.mkDerivation {
    pname = "deepseek-harness-landlock";
    inherit (finalAttrs) version src;
    buildPhase = ''
      $CC -std=c11 -Os -Wall -Wextra -Werror -static -s \
        native/system/packages/entry/src/main.c -o landlock-run
    '';
    installPhase = ''
      install -Dm755 landlock-run "$out/bin/landlock-run"
    '';
  };

  passthru.primaryRuntime = callPackage ./primary-runtime.nix {
    inherit pnpm;
    inherit (finalAttrs) version;
  };

  passthru.electron = electron;

  meta = {
    description = "DeepSeek Harness desktop application";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "deepseek-harness";
  };
})
