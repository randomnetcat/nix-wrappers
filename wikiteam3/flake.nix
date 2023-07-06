{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.poetry2nix = {
    url = "github:nix-community/poetry2nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.wikiteam3 = {
    url = "github:elsiehupp/wikiteam3";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, wikiteam3 }: 
    let
      appNames = [ "dumpgenerator" "launcher" "uploader" ];
    in
    {
      # Nixpkgs overlay providing the application
      overlay = nixpkgs.lib.composeManyExtensions [
        poetry2nix.overlay
        (final: prev:
          {
            # The application
            dumpgenerator =
              let
                basePackage = prev.poetry2nix.mkPoetryApplication {
                  projectDir = wikiteam3;
                  preferWheels = true;
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
