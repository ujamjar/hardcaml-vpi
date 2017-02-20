#require "hardcaml";;

open HardCaml
open Signal.Comb
open Signal.Seq

let f a b = reg r_sync enable (a +: b)
let c = output "c" (f (input "a" 8) (input "b" 8))
let circ = Circuit.make "test" [c]

module B = Bits.Comb.IntbitsList
module C = Cosim2.Make(B)
module Cs = Cyclesim.Api

let sim = C.make circ

let () = 
  let enable = Cs.in_port sim "enable" in
  let a = Cs.in_port sim "a" in
  let b = Cs.in_port sim "b" in
  let c = Cs.out_port sim "c" in
  Cs.reset sim;

  enable := B.vdd;

  a := B.consti 8 10;
  b := B.consti 8 20;
  Cs.cycle sim;
  Printf.printf "%i\n" (B.to_int !c);

  a := B.consti 8 11;
  b := B.consti 8 22;
  Cs.cycle sim;
  Printf.printf "%i\n" (B.to_int !c);

  Cs.cycle sim;
  Printf.printf "%i\n" (B.to_int !c);

  Cs.cycle sim;
  Printf.printf "%i\n" (B.to_int !c);

  ()

