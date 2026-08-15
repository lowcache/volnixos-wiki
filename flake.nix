{
  description = "Volatile NixOS wiki — pinned Hugo toolchain for reproducible builds";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Pinned by flake.lock. `make build` resolves Hugo through here rather than
      # `nixpkgs#hugo`, which follows the local registry and silently drifts —
      # a drift between Hugo releases changes rendered output. Same reasoning as
      # the blog's flake; the two sites pin independently on purpose.
      #
      # `pagefind` is here because search is a post-build step: E25DX ships
      # `enablePageFind` but expects you to run pagefind over the output
      # yourself (see build.sh).
      packages.${system} = {
        inherit (pkgs)
          hugo
          go
          wrangler
          pagefind
          ;
        default = pkgs.hugo;
      };

      # `go` is required alongside Hugo: the theme is a Hugo Module, and module
      # resolution shells out to the go binary. No git submodules anywhere.
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.hugo
          pkgs.go
          pkgs.wrangler
          pkgs.pagefind
        ];
      };
    };
}
