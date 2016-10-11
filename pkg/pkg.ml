#!/usr/bin/env ocaml
#use "topfind"
#require "topkg,astring"
open Topkg

let () = 
  Pkg.describe "hardcaml-vpi" @@ fun c ->
  Ok ([
    Pkg.lib "cosim.vpi";
    Pkg.lib ~built:false "hardcaml_vvp.sh"
  ])

