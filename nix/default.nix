let
  pkgs = import <nixpkgs> {};
in
pkgs.buildEnv {
  name = "lago";
  paths = with pkgs; [
    docker
    caddy
  ];
}
