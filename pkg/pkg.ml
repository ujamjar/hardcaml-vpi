#!/usr/bin/env ocaml
#use "topfind"
#require "topkg,astring"
open Topkg

let ivl = Conf.with_pkg ~default:false "ivl"
let mti = Conf.with_pkg ~default:false "mti"

let () = 
  Pkg.describe "hardcaml-vpi" @@ fun c ->
  let ivl = Conf.value c ivl in
  let mti = Conf.value c mti in
  Ok ([
    Pkg.lib ~cond:ivl "cosim.vpi";
    Pkg.lib ~cond:mti "hc_mti.vpi";
    Pkg.lib ~cond:mti "hc_mti64.vpi";
    Pkg.lib ~cond:false "hc_cvc.vpi";
    Pkg.lib ~cond:ivl "hc_ivl.vpi";
    Pkg.bin ~auto:false "hardcaml_vvp.sh"
  ])

