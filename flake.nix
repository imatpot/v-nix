{
  description = "Weekly release of the V programming language";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pname = "vlang";
      version = "weekly.2022.41";
    in
    {
      overlays.${system}.default = final: prev: {
        vlang = self.packages.${system}.default;
      };

      packages.${system}.default = pkgs.stdenv.mkDerivation rec {
        inherit pname version;

        src = builtins.fetchTarball {
          url = "https://github.com/vlang/v/releases/download/${version}/v_linux.zip";
          sha256 = "16y6r4962q2x9zczdr3mlmifj0nxc8d3bk4ijp2i2ya8nggr7lza";
        };

        markdown = pkgs.fetchFromGitHub {
          owner = "vlang";
          repo = "markdown";
          rev = "014724a2e35c0a7e46ea9cc91f5a303f2581b62c";
          sha256 = "08gl20f0a4bbxf9gr1nqbcmhphcqzmv8c45l587h8dkkm2dzghlf";
        };

        nativeBuildInputs = with pkgs; [
          patchelf
          glibc
        ];

        dontBuild = true;
        binaryInterpreter = "${pkgs.glibc}/lib64/ld-linux-x86-64.so.2";

        preInstall = ''
          export HOME=$(mktemp -d)
          export VFLAGS="-cc cc"

          # Patch executables to use the correct interpreter
          patchelf --set-interpreter ${binaryInterpreter} v
          patchelf --set-interpreter ${binaryInterpreter} thirdparty/tcc/tcc.exe

          # Requires git, so we skip its compilation
          mv cmd/tools/vcreate_test.v $HOME/vcreate_test.v
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/{bin,lib,share}
          cp -r examples $out/share
          cp -r {cmd,vlib,thirdparty} $out/lib
          cp v $out/lib
          ln -s $out/lib/v $out/bin/v

          mkdir -p $HOME/.vmodules;
          ln -sf ${markdown} $HOME/.vmodules/markdown

          $out/lib/v build-tools
          $out/lib/v $out/lib/cmd/tools/vdoc
          $out/lib/v $out/lib/cmd/tools/vast
          $out/lib/v $out/lib/cmd/tools/vvet

          runHook postInstall
        '';

        postInstall = ''
          mv $HOME/vcreate_test.v $out/lib/cmd/tools/vcreate_test.v
        '';

        preFixup = ''
          # Uses a weird shebang, so we prevent patchelf from killing itself
          mv $out/lib/vlib/v/tests/script_with_no_extension $HOME/script_with_no_extension
        '';

        postFixup = ''
          mv $HOME/script_with_no_extension $out/lib/vlib/v/tests/script_with_no_extension
        '';
      };
    };
}
