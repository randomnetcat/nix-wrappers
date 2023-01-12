{
  inputs.dream2nix = {
    url = "github:nix-community/dream2nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nix-pypi-fetcher.url = "github:DavHau/nix-pypi-fetcher-2"; # Original version of the repo is outdated and no longer updated
  };

  inputs.wikiteam3 = {
    url = "github:elsiehupp/wikiteam3";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, dream2nix, wikiteam3 }: 
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

        cleanSource = pkgs.runCommandLocal "wikiteam3-clean" { ORIG_SOURCE = wikiteam3; } ''
          cp -rT --no-preserve=mode,ownership -- "$ORIG_SOURCE" "$out"
          rm -r -- "$out/dist"
        '';

        # I hate this so much. But I couldn't get just setting config.packagesDir for some reason
        # and I don't care enough to dig into dream2nix to figure out why. So! Just create build
        # a new directory that links to the correct lockfile based on the system we're building
        # for. We have to do this because lxml resolves to a different file on different architectures.
        # AAAAAAAAA it's 4:30am good night? morning? why
        cleanPackage = pkgs.runCommandLocal "dream2nix-input" { ORIG_SOURCE = ./.; NIX_SYSTEM = system; } ''
          mkdir -- "$out"
          ln -sT -- "''${ORIG_SOURCE}/dream2nix-packages-''${NIX_SYSTEM}" "$out/dream2nix-packages"
        '';

        underlying =
          (dream2nix.lib.makeFlakeOutputs {
            inherit systems;
            config.projectRoot = cleanPackage;
            source = cleanSource;
            projects = ./projects.toml;
          });
        appNames = [ "dumpgenerator" "launcher" "uploader" ];
        rawPackage = underlying.packages."${system}".default;
        wrappedPackage = pkgs.linkFarm "wikiteam3-wrapped" (map (app: { name = "bin/wikiteam-${app}"; path = "${rawPackage}/bin/${app}"; }) appNames);
      in
      rec {
        packages = {
          dumpgenerator = wrappedPackage;
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
            dreamResolveImpure = {
              type = "app";
              program = "${underlying.packages."${system}".resolveImpure}/bin/resolve";
            };
          };
      }
   );
}
