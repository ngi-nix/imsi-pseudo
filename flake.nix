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

    imsi-pseudo-src = {
      url = "git+https://git.osmocom.org/imsi-pseudo";
      flake = false;
    };

  };


  outputs =
    { self
    , nixpkgs
    , pycrypto-src
    , simtools-src
    , imsi-pseudo-src
    , ...
    }:
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

        pycrypto =
          with final.python2Packages;
          buildPythonPackage {
            pname = "pycrypto";
            version = "2.6.1";
            src = pycrypto-src;
          };

        shadysim =
          with final.python2Packages;
          buildPythonApplication {
            pname = "shadysim";
            version = "0.1.0";
            src = "${simtools-src}/shadysim";

            postPatch = ''
              cat << EOF > setup.py
              #!/usr/bin/env python

              from setuptools import setup, find_packages

              setup(
                  name="shadysim",
                  version="1.0",
                  # Modules to import from other scripts:
                  packages=find_packages(),
                  # Executables
                  scripts=["shadysim.py"],
              )
              EOF
            '';

            postInstall = ''
              mv $out/bin/shadysim.py $out/bin/shadysim
            '';

            propagatedBuildInputs = [
              pycrypto
            ];
          };

        converter =
          let
            jflags = "-classpath ${simtools-src}/javacard/bin/converter.jar";
            jdk = final.adoptopenjdk-jre-hotspot-bin-8;
          in
          with final;
          pkgs.writeScriptBin "converter" ''
            ${jdk}/bin/java ${jflags} com.sun.javacard.converter.Converter "$@"
          '';

      };


      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) shadysim converter;
      });


      defaultPackage =
        forAllSystems (system: self.packages.${system}.shadysim);

      # exposes the makefile's phony targets to all systems
      apps = forAllSystems
        (system:
          let
            pkgs = nixpkgsFor."${system}";

            oldJdk = pkgs.adoptopenjdk-openj9-bin-8;

            phony-targets = [
              "flash"
              "list"
              "remove"
              "reflash"
            ];

            mkPhonyDerivation = with pkgs; (target: stdenv.mkDerivation {
              pname = "imsi-pseudo";
              version = "0.1.0";
              src = "${imsi-pseudo-src}/sim-applet";

              buildInputs = [ oldJdk ];
              nativeBuildInputs = [ gnumake ];
              prePatch = ''
                substituteInPlace Makefile \
                    --replace '../../sim-tools' ${simtools-src}
                substituteInPlace applet-project.mk \
                    --replace '$(SIMTOOLS_DIR)/bin/shadysim' ${shadysim}/bin/shadysim
              '';

              buildPhase = ''
                make ${target}
              '';
              dontInstall = true;
            });
          in
          pkgs.lib.genAttrs phony-targets (target: {
            type = "app";
            program = "${mkPhonyDerivation target}";
          })
        );


    };

}
