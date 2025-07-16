{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    wikiteam3 = {
      url = "github:mediawiki-client-tools/mediawiki-dump-generator/uv";
      flake = false;
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, wikiteam3, pyproject-nix, uv2nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        appNames = [ "dumpgenerator" "launcher" "uploader" ];

        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        python = pkgs.python3;

        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = "${wikiteam3}";
        };

        projectOverlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        buildSystemOverlay = final: prev:
          let
            inherit (final) resolveBuildSystem;

            buildSystemOverrides = {
              docopt.setuptools = [ ];
              pywikibot.setuptools = [ ];
            };
          in
          lib.mapAttrs
            (name: spec: prev.${name}.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ (resolveBuildSystem spec);
            }))
            buildSystemOverrides;

        pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            projectOverlay
            buildSystemOverlay
          ]
        );
      in
      {
        packages = {
          virtualEnv = pythonSet.mkVirtualEnv "wikiteam3-env" workspace.deps.default;

          dumpgenerator = nixpkgs.legacyPackages.${system}.linkFarm "wikiteam3-wrapped" (
            map (app: {
              name = "bin/wikiteam-${app}";
              path = "${self.packages.${system}.virtualEnv}/bin/${app}";
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
      });
}
