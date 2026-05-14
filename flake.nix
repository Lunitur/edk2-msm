{
  description = "EDK2 UEFI firmware for Qualcomm Snapdragon platforms";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
      crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;

      # Cross-compiler with aarch64-linux-gnu- prefix.
      # nixpkgs uses aarch64-unknown-linux-gnu- but the project expects aarch64-linux-gnu-.
      crossToolchain = pkgs.symlinkJoin {
        name = "aarch64-linux-gnu-toolchain";
        paths = [ crossPkgs.buildPackages.gcc ];
        postBuild = ''
          cd $out/bin
          for f in aarch64-unknown-linux-gnu-*; do
            ln -sf "$f" "''${f/aarch64-unknown-linux-gnu/aarch64-linux-gnu}"
          done
        '';
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "vayu-edk";

        buildInputs = with pkgs; [
          crossToolchain
          clang
          lld
          gnumake
          python3
          gettext
          git
          bash
          dtc
          acpica-tools
        ];

        CROSS_COMPILE = "aarch64-linux-gnu-";

        shellHook = ''
          echo "vayu-edk dev shell"
          echo "  cross-compiler: aarch64-linux-gnu- (gcc $(aarch64-linux-gnu-gcc -dumpversion 2>/dev/null || echo unknown))"
          echo "  clang: $(clang --version | head -1)"
          echo "  usage: build.sh --device vayu"
          echo "  devices: $(ls configs/devices/ | sed 's/.conf//' | tr '\n' ' ')"
        '';
      };
    });
}
