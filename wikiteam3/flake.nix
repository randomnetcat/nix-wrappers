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
                pyPkgs = final.python3.pkgs;

                basePackage = pyPkgs.buildPythonApplication {
                  name = "mediawiki-dump-generator";
                  src = "${wikiteam3}";
                  pyproject = true;

                  buildInputs = [
                    pyPkgs.poetry-core
                  ];

                  propagatedBuildInputs = [
                    pyPkgs.requests
                    pyPkgs.internetarchive
                    pyPkgs.lxml
                    pyPkgs.mwclient
                    pyPkgs.pymysql
                    pyPkgs.urllib3
                    pyPkgs.file-read-backwards

                    (pyPkgs.buildPythonPackage rec {
                      pname = "wikitools3";
                      version = "3.0.1";

                      src = pyPkgs.fetchPypi {
                        inherit pname version;
                        sha256 = "tJPmgG+xmFrRrylMVjZK66bqZ6NmVTvBG2W39SedABI=";
                      };

                      doCheck = false;

                      propagatedBuildInputs = [
                        (pyPkgs.buildPythonPackage rec {
                          pname = "poster3";
                          version = "0.8.1";
                          format = "wheel";

                          src = pyPkgs.fetchPypi {
                            inherit pname version format;
                            sha256 = "GyfX1j4xkeXXI4Yx/IKORJNZDpTc6gNOOGwHnYU8zhQ=";
                            dist = "py3";
                            python = "py3";
                          };

                          doCheck = false;
                        })
                      ];
                    })
                  ];
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
