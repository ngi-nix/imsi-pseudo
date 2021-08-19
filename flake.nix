{
  description = "Shadysim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.05";
    pycrypto-src = {
      url = "github:pycrypto/pycrypto";
      flake = false;
    };
    simtools-src = {
      url = "git+https://git.osmocom.org/sim/sim-tools";
      flake = false;
    };
  };


  outputs = { self, nixpkgs, pycrypto-src, simtools-src, ... }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }
      );

    in
    {

      overlay = final: prev: rec {

        pycrypto = with final.python2Packages;
          buildPythonPackage {
            pname = "pycrypto";
            version = "0.1.0";
            src = pycrypto-src;
          };

        shadysim =
          { python2
          , python2Packages
          }:

            with python2Packages;
            buildPythonApplication {
              name = "shadysim";
              version = "0.1.0";
              src = "${simtools-src}/shadysim";

              patches = [
                ./patches/0001-add-setup-py.patch
              ];

              postInstall = ''
                mv $out/bin/shadysim{.py,}
              '';

              propagatedBuildInputs = [
                pycrypto
              ];
            };

        shadysim-bin = with final; callPackage shadysim { };

      };

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) shadysim-bin;
      });


      defaultPackage =
        forAllSystems (system: self.packages.${system}.shadysim-bin);

    };

}
