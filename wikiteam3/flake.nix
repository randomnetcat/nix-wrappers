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

        underlying =
          (dream2nix.lib.makeFlakeOutputs {
            inherit systems;

            # The lxml dependency resolves to a different file based on the architecture, so we have to have
            # two different lockfiles. This dynamically selects the project folder based on the system we
            # are building for.
            config.projectRoot = ./system- + system;

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
