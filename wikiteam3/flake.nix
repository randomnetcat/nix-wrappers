{
  description = "Application packaged using poetry2nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.mach-nix = {
    url = "github:DavHau/mach-nix";

    # Disabled because dependency information repository auto-update is broken and thus outdated, causing an error in mach-nix.
    # inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.wikiteam3 = {
    url = "github:elsiehupp/wikiteam3";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, wikiteam3 }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };

        lib = nixpkgs.lib;

        pythonPkg = mach-nix.lib."${system}".buildPythonApplication {
          pname = "dumpgenerator";
          version = (builtins.fromTOML (builtins.readFile "${wikiteam3}/pyproject.toml")).tool.poetry.version;

          src = "${wikiteam3}/dist/wikiteam3-3.0.0-py3-none-any.whl";
          format = "wheel";

          pipInstallFlags = [ "--no-deps" ]; # Ignore argparse because it exists in stdlib

          requirements =
            let
              rawText = builtins.readFile "${wikiteam3}/requirements.txt";
              rawLines = lib.splitString "\n" rawText;
              mainLines = lib.filter (x: !(lib.strings.hasPrefix " " x)) rawLines;
              mainLineHeads = map (x: lib.head (lib.splitString " " x)) mainLines;
              filteredMainLineHeads = lib.filter (x: !(lib.strings.hasPrefix "argparse==" x)) mainLineHeads;
            in
              lib.concatStringsSep "\n" filteredMainLineHeads;
        };
      in
      rec {
        packages = {
          dumpgenerator = pythonPkg;

          default = packages.dumpgenerator;
        };

        apps = {
          dumpgenerator = {
            type = "app";
            program = "${packages.dumpgenerator}/bin/dumpgenerator";
          };

          default = apps.dumpgenerator;
        };
      }));
}
