{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wikiteam3 = {
      url = "github:mediawiki-client-tools/mediawiki-dump-generator";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, wikiteam3 }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
        pkgs = nixpkgs.legacyPackages.${system};
        instance = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };
        inherit (instance) mkPoetryApplication;
        appNames = [ "dumpgenerator" "launcher" "uploader" ];
      in
      {
        packages = {
          unwrapped = mkPoetryApplication {
            projectDir = "${wikiteam3}";

            overrides = instance.overrides.withDefaults (final: prev: {
              pre-commit-poetry-export = prev.pre-commit-poetry-export.override {
                preferWheel = true;
              };

              wikitools3 = prev.wikitools3.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or []) ++ [final.poetry];
              });
            });
          };

          dumpgenerator = nixpkgs.legacyPackages.${system}.linkFarm "wikiteam3-wrapped" (
            map (app: {
              name = "bin/wikiteam-${app}";
              path = "${self.packages.${system}.unwrapped}/bin/${app}";
            }) appNames
          );

          default = self.packages.${system}.dumpgenerator;
        };

        apps = nixpkgs.lib.genAttrs appNames (app: {
          type = "app";
          program = "${self.packages.${system}.dumpgenerator}/bin/wikiteam-${app}";
        }) // {
          default = self.apps.${system}.dumpgenerator;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.dumpgenerator ];
          packages = [ pkgs.poetry ];
        };
      });
}
