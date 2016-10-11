LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`ocamlc -where` vvp -M`opam config var hardcaml-vpi:lib` -mcosim $1
