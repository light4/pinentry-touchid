{
  description = "Native macOS GnuPG pinentry with opt-in Keychain caching and Touch ID";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          pinentry-touchid = pkgs.callPackage ./nix/package.nix {
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./Sources
                ./scripts/e2e.py
              ];
            };
          };
          default = pinentry-touchid;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          meta = self.packages.${system}.default.meta;
          program = "${self.packages.${system}.default}/bin/pinentry-touchid";
        };
      });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) pinentry-touchid;
      });
    };
}
