with import <nixpkgs> { };

stdenv.mkDerivation rec {
  name = "env";
  env = buildEnv { name = name; paths = buildInputs; };
  buildInputs = [
    elixir
    elixir_ls
    inotify-tools
    watchexec
  ];
}
