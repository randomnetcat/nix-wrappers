{
  inputs.dream2nix = {
    url = "github:nix-community/dream2nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nix-pypi-fetcher.url = "github:DavHau/nix-pypi-fetcher-2";
  };

  inputs.wikiteam3 = {
    url = "github:elsiehupp/wikiteam3";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, dream2nix, wikiteam3 }: 
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        cleanSource = pkgs.runCommandLocal "wikiteam3-clean" { ORIG_SOURCE = wikiteam3; } ''
          echo $ORIG_SOURCE and $out
          cp -rT --no-preserve=mode,ownership -- "$ORIG_SOURCE" "$out"
          rm -r -- "$out/dist"
        '';
        underlying =
          (dream2nix.lib.makeFlakeOutputs {
            inherit systems;
            config.projectRoot = ./.;
            source = cleanSource;
            projects = ./projects.toml;
          });
      in
      (u:
      builtins.break
      {
      }) underlying
    );
}
