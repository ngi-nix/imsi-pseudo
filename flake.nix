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

        converter-bin =
          let
            CLASSPATH = "${simtools-src}/javacard/bin/converter.jar";
            JFLAGS = "-classpath ${CLASSPATH}";
            jdk = final.adoptopenjdk-jre-hotspot-bin-8;
          in
          with final;
          pkgs.runCommand
            "converter"
            {
              inherit CLASSPATH;
              inherit JFLAGS;
            }
            ''
              mkdir -p $out/bin
              cat << EOF > $out/bin/converter
              ${jdk}/bin/java \
                $JFLAGS com.sun.javacard.converter.Converter "$@"
              EOF
              chmod +x $out/bin/converter
            '';

        # this package is not a program, it uses phony make targets
        # as wrappers around shadysim and converter
        imsi-pseudo = with final;
          let
            oldJdk = final.adoptopenjdk-openj9-bin-8;
          in
          stdenv.mkDerivation {
            name = "imsi-pseudo";
            version = "0.1.0";
            src = "${imsi-pseudo-src}/sim-applet";

            nativeBuildInputs = [ oldJdk ];
            prePatch = ''
              substituteInPlace Makefile \
                  --replace '../../sim-tools' ${simtools-src}
              substituteInPlace applet-project.mk \
                  --replace '$(SIMTOOLS_DIR)/bin/shadysim' ${shadysim-bin}/bin/shadysim
            '';

            dontBuild = true;
            dontInstall = true;
          };

      };


      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) shadysim-bin converter-bin imsi-pseudo;
      });


      defaultPackage =
        forAllSystems (system: self.packages.${system}.shadysim-bin);

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
              name = "imsi-pseudo";
              version = "0.1.0";
              src = "${imsi-pseudo-src}/sim-applet";

              buildInputs = [ oldJdk ];
              nativeBuildInputs = [ gnumake ];
              prePatch = ''
                substituteInPlace Makefile \
                    --replace '../../sim-tools' ${simtools-src}
                substituteInPlace applet-project.mk \
                    --replace '$(SIMTOOLS_DIR)/bin/shadysim' ${shadysim-bin}/bin/shadysim
              '';

              buildPhase = ''
                make ${target}
              '';
              dontInstall = true;
            });
          in
          builtins.listToAttrs
            (builtins.map
              (target:
                {
                  name = "${target}";
                  value = {
                    type = "app";
                    program = "${mkPhonyDerivation target}";
                  };
                })
              phony-targets
            )
        );


    };

}
