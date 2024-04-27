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

            # Prevent poetry2nix from getting into an infinite loop.
            #
            # poetry2nix tries to clean the source by removing all .gitignored
            # files. In order to do this, it attempts to traverse the
            # filesystem until it either (a) finds a .git directory or (b)
            # reaches /. HOWEVER, because we're passing it a store path as a
            # string, when it attempts to append "/.." to go up a directory, it
            # instead just appends that literally. So, it gets stuck in an
            # infinite loop considering "/nix/foo-source",
            # "/nix/foo-source/..", "/nix/foo-source/../..", etc. This results
            # in a stack overflow, because of course it does.
            #
            # Passing src forces this directory to be used as the final src,
            # rather than cleaning.
            #
            # Fuck you, poetry2nix. I've been able to coerce you into working,
            # but you've given me problems every step of the way.
            src = "${wikiteam3}";

            overrides = instance.overrides.withDefaults (final: prev: {
              pre-commit-poetry-export = prev.pre-commit-poetry-export.override {
                preferWheel = true;
              };

              # PyYAML apparently has a build issue: https://github.com/yaml/pyyaml/issues/601
              # Use the pre-built wheel to work around this.
              pyyaml = prev.pyyaml.override {
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
