{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  zlib,
  libxcrypt-legacy,
  nodejs,
  pnpm,
  version,
}:
let
  lock = lib.importJSON ../scripts/primary-runtime/lock.json;
  target = lock.targets.linux-x64;
  pythonArchive = fetchurl {
    url = "https://github.com/astral-sh/python-build-standalone/releases/download/${lock.pythonRelease}/cpython-${lock.pythonVersion}%2B${lock.pythonRelease}-${target.pythonTarget}-install_only_stripped.tar.gz";
    sha256 = target.pythonSha256;
  };
  wheels = map (wheel: fetchurl { inherit (wheel) url sha256; }) (target.wheels ++ lock.wheels);
  manifest = builtins.toJSON {
    desktopVersion = version;
    platform = "linux";
    arch = "x64";
    python = lock.pythonVersion;
    node = nodejs.version;
    pnpm = pnpm.version;
    inherit (lock) pythonPackages;
  };
in
stdenv.mkDerivation {
  pname = "deepseek-harness-primary-runtime";
  inherit version;
  dontUnpack = true;
  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    libxcrypt-legacy
  ];
  dontStrip = true;
  # The standalone interpreter is BOLT-optimized; sorting its ELF sections
  # corrupts the dynamic symbol table. Only the autoPatchelf pass may edit it.
  dontPatchELF = true;
  patchelfFlags = [ "--no-sort" ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/dependencies"
    tar -xzf ${pythonArchive} -C "$out/dependencies"
    sitePackages="$out/dependencies/python/lib/python3.12/site-packages"
    for wheel in ${lib.escapeShellArgs wheels}; do
      unzip -oq "$wheel" -d "$sitePackages"
    done
    mkdir -p "$out/dependencies/node/bin" "$out/dependencies/node/node_modules"
    ln -s ${nodejs}/bin/node "$out/dependencies/node/bin/node"
    ln -s ${pnpm}/libexec/pnpm "$out/dependencies/pnpm"
    printf '%s\n' ${lib.escapeShellArg manifest} > "$out/runtime.json"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/dependencies/python/bin/python3" -I -B -c \
      'import numpy, pandas, docx, pptx, openpyxl, PIL, lxml, xlsxwriter; assert numpy.arange(4).sum() == 6'
    "$out/dependencies/python/bin/python3" -I -B -m pip check
    runHook postInstallCheck
  '';
}
