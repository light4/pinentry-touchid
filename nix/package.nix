{
  lib,
  swiftPackages,
  swift,
  python3,
  src,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "pinentry-touchid";
  version = "0.1.0";
  inherit src;

  strictDeps = true;
  nativeBuildInputs = [ swift ];
  nativeCheckInputs = [ python3 ];
  dontConfigure = true;

  # There are no package dependencies. Compile directly so nixpkgs' Swift 5.10
  # can build the sources without evaluating the Swift 6 SwiftPM manifest.
  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    swiftc -O -whole-module-optimization -parse-as-library \
      -module-name PinentryTouchID \
      Sources/PinentryTouchID/*.swift -o pinentry-touchid
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 scripts/e2e.py --binary "$PWD/pinentry-touchid"
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 pinentry-touchid "$out/bin/pinentry-touchid"
    runHook postInstall
  '';

  meta = {
    description = "Native macOS GnuPG pinentry with Touch ID";
    homepage = "https://github.com/light4/pinentry-touchid";
    platforms = lib.platforms.darwin;
    mainProgram = "pinentry-touchid";
  };
}
