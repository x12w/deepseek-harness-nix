{
  description = "DeepSeek Harness Linux desktop for NixOS";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      harness = pkgs.callPackage ./nix {
        sourceRevision = nixpkgs.lib.removeSuffix "-dirty" (
          self.rev or self.dirtyRev or "0000000000000000000000000000000000000000"
        );
      };
    in
    {
      packages.${system} = {
        default = harness;
        deepseek-harness = harness;
      };
      apps.${system}.default = {
        type = "app";
        program = "${harness}/bin/deepseek-harness";
        meta.description = "DeepSeek Harness desktop";
      };
      checks.${system}.desktop = harness;
      formatter.${system} = pkgs.nixfmt;
    };
}
