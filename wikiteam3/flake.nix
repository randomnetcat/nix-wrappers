{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.wikiteam3 = {
    url = "github:elsiehupp/wikiteam3";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, wikiteam3 }:
    let
      appNames = [ "dumpgenerator" "launcher" "uploader" ];
    in
    {
      # Nixpkgs overlay providing the application
      overlay = nixpkgs.lib.composeManyExtensions [
        (final: prev:
          {
            # The application
            dumpgenerator =
              let
                basePackage = final.poetry2nix.mkPoetryApplication {
                  projectDir = wikiteam3;

                  overrides = final.poetry2nix.overrides.withDefaults (final: prev: {
                    pre-commit-poetry-export = prev.pre-commit-poetry-export.overridePythonAttrs (old: {
                      buildInputs = (old.buildInputs or []) ++ [final.poetry];
                    });

                    wikitools3 = prev.wikitools3.overridePythonAttrs (old: {
                      buildInputs = (old.buildInputs or []) ++ [final.poetry];
                    });
                  });
                };

                wrappedPackage = prev.linkFarm "wikiteam3-wrapped" (
                  map (app: {
                    name = "bin/wikiteam-${app}";
                    path = "${basePackage}/bin/${app}";
                  }) appNames
                );
              in
              wrappedPackage;
          }
        )
      ];
    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };

        lib = nixpkgs.lib;
      in
      rec {
        packages = {
          dumpgenerator = pkgs.dumpgenerator;
          default = packages.dumpgenerator;
        };

        apps =
          let
            base = lib.genAttrs appNames (app: {
              type = "app";
              program = "${packages.dumpgenerator}/bin/wikiteam-${app}";
            });
          in
          base // {
            default = base.dumpgenerator;
          };
      }
   ));
}
