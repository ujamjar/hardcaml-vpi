#!/usr/bin/env ocaml
#use "topfind"
#require "topkg,astring"
open Topkg

let () = 
  Pkg.describe "hardcaml-vpi" @@ fun c ->
  Ok ([
    Pkg.lib "cosim.vpi";
    Pkg.lib "hc_mti.vpi";
    Pkg.lib "hc_cvc.vpi";
    Pkg.lib "hc_ivl.vpi";
    Pkg.bin ~auto:false "hardcaml_vvp.sh"
  ])

