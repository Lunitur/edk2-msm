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

      # GCC wrapper: suppresses -Werror=unused-result (GCC 15 compat, SimpleInit rootfs)
      hostcc = pkgs.writeShellScriptBin "gcc-wrap" ''
        exec ${pkgs.gcc}/bin/gcc -Wno-error=unused-result "$@"
      '';

      # cc + gcc wrappers: force -std=gnu17 (GCC 15 defaults to C23, EDK2 BaseTools needs old C)
      cc-gnu17 = pkgs.writeShellScriptBin "cc" ''
        exec ${pkgs.gcc}/bin/gcc -std=gnu17 "$@"
      '';
      gcc-gnu17 = pkgs.writeShellScriptBin "gcc" ''
        exec ${pkgs.gcc}/bin/gcc -std=gnu17 "$@"
      '';
    in {
      devShells.default = pkgs.mkShell {
        name = "vayu-edk";

        buildInputs = with pkgs; [
          crossToolchain
          clang
          lld
          llvm
          gnumake
          python3
          gettext
          git
          bash
          dtc
          acpica-tools
          util-linux
          hostcc
          cc-gnu17
          gcc-gnu17
        ];

        CROSS_COMPILE = "aarch64-linux-gnu-";

        shellHook = ''
          export HOSTCC="${hostcc}/bin/gcc-wrap"
          export PATH="${gcc-gnu17}/bin:${cc-gnu17}/bin:$PATH"
          # stdenv sets CC=gcc but gen-rootfs-source.sh wants cross-compiler for target objects.
          unset CC CXX
          echo "vayu-edk dev shell"
          echo "  cross-compiler: aarch64-linux-gnu- (gcc $(aarch64-linux-gnu-gcc -dumpversion 2>/dev/null || echo unknown))"
          echo "  clang: $(clang --version | head -1)"
          echo "  usage: build.sh --device vayu"
        '';
      };
    });
}
